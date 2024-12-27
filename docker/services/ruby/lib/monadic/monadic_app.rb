# frozen_string_literal: true

require_relative "./utils/basic_agent"
require_relative "./utils/string_utils"

Dir.glob(File.expand_path("helpers/**/*.rb", __dir__)).sort.each do |rb|
  require rb
end

user_helpers_dir = if IN_CONTAINER
                    "/monadic/data/plugins/**/helpers"
                  else
                    Dir.home + "/monadic/data/plugins/**/helpers"
                  end

Dir.glob(File.expand_path(user_helpers_dir + "/**/*.rb")).sort.each do |rb|
  require rb
end

class MonadicApp
  include MonadicAgent
  include MonadicHelper
  include StringUtils

  TOKENIZER = FlaskAppClient.new

  # script directory to store the system scripts
  SYSTEM_SCRIPT_DIR = "/monadic/scripts"
  # script directory to store the user scripts
  USER_SCRIPT_DIR = "/monadic/data/scripts"
  # shared volume between the containers
  SHARED_VOL = "/monadic/data"

  # script directory in the dev mode (= when ruby-container is not used)
  LOCAL_SYSTEM_SCRIPT_DIR = File.expand_path(File.join(__dir__, "..", "..", "scripts"))
  # script directory in the local computer to store the user scripts
  LOCAL_USER_SCRIPT_DIR = File.expand_path(File.join(Dir.home, "monadic", "data", "scripts"))
  # shared volume in the local computer to share with the containers
  LOCAL_SHARED_VOL = File.expand_path(File.join(Dir.home, "monadic", "data"))

  AI_USER_INITIAL_PROMPT = <<~PROMPT
      The user is currently answering various types of questions, writing computer program code, making decent suggestions, and giving helpful advice on your message. Give the user requests, suggestions, or questions so that the conversation is engaging and interesting. If there are any errors in the responses you get, point them out and ask for correction. Use the same language as the user.

      Keep on pretending as if you were the "user" and as if the user were the "assistant" throughout the conversation.

      Do your best to make the conversation as natural as possible. Do not change subjects unless it is necessary, and keep the conversation going by asking questions or making comments relevant to the preceding and current topics.

      Your response should be concise and clear. Even if the preceding messages are formatted as json, you keep your response as plain text. do not use parentheses or brackets in your response.

      Remember you are the one who inquires for information, not providing the answers.
  PROMPT

  # access the flask app client so that it gets ready before the first request

  attr_accessor :api_key, :context, :embeddings_db, :settings

  def initialize
    @context = {}
    @api_key = ""
    @embeddings_db = nil
    @settings = {}
  end

  # Wrap the user's message in a monad
  def monadic_unit(message)
    res = { "message": message,
            "context": @context }
    res.to_json
  end

  # Unwrap the monad and return the message
  def monadic_unwrap(monad)
    JSON.parse(monad)
  rescue JSON::ParserError
    { "message" => monad.to_s, "context" => @context }
  end

  # sanitize the data to remove invalid characters
  def sanitize_data(data)
    if data.is_a? String
      return data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    end

    if data.is_a? Hash
      data.each do |key, value|
        data[key] = sanitize_data(value)
      end
    elsif data.is_a? Array
      data.map! do |value|
        sanitize_data(value)
      end
    end

    data
  end

  # Unwrap the monad and return the message after applying a given process (if any)
  def monadic_map(monad)
    obj = monadic_unwrap(monad)
    @context = block_given? ? yield(obj["context"]) : obj["context"]
    JSON.pretty_generate(sanitize_data(obj))
  end

  # Convert a monad to HTML
  def monadic_html(monad)
    obj = monadic_unwrap(monad)
    json2html(obj, mathjax: settings["mathjax"])
  end

  # Convert snake_case to space ceparated capitalized words
  def snake2cap(snake)
    snake.split("_").map(&:capitalize).join(" ")
  rescue StandardError
    snake
  end

  # Execute a command in a specified container with retry and timeout functionality
  # @param command [String] The command to execute
  # @param container [String] The container type ("ruby", "python", or custom)
  # @param success [String] Success message to return
  # @param timeout [Integer] Maximum time in seconds to wait for command completion
  # @param retries [Integer] Number of retry attempts
  # @param retry_delay [Float] Delay between retries in seconds
  # @param block [Block] Optional block for custom output handling
  # @return [String] Command execution result or error message
  def send_command(command:,
                   container: "python",
                   success: "Command executed successfully",
                   timeout: 300,
                   retries: 3,
                   retry_delay: 1.5,
                   &block)
      
    # Prepare the system command based on container type
    case container.to_s
    when "ruby"
      # Set appropriate paths based on environment (container or local)
      if IN_CONTAINER
        system_script_dir = SYSTEM_SCRIPT_DIR
        user_script_dir = USER_SCRIPT_DIR
        shared_volume = SHARED_VOL
      else
        system_script_dir = LOCAL_SYSTEM_SCRIPT_DIR
        user_script_dir = LOCAL_USER_SCRIPT_DIR
        shared_volume = LOCAL_SHARED_VOL
      end
      
      # Construct command for Ruby environment
      system_command = <<~SYS
        find #{system_script_dir} -type f -exec chmod +x {} + 2>/dev/null | : && \
        find #{user_script_dir} -type f -exec chmod +x {} + 2>/dev/null | : && \
        export PATH="#{system_script_dir}:${PATH}" && \
        export PATH="#{user_script_dir}:${PATH}" && \
        cd #{shared_volume} && \
        #{command}
      SYS
    when "python"
      # Set container name for Python environment
      container = "monadic-chat-python-container"
      # Construct command for Python container
      system_command = <<~DOCKER
        docker exec #{container} bash -c 'find #{USER_SCRIPT_DIR} -type f -exec chmod +x {} +' && \
        docker exec -w #{SHARED_VOL} #{container} #{command}
      DOCKER
    else
      # Set container name for custom container types
      container = "monadic-chat-#{container}-container"
      # Construct command for custom container
      system_command = <<~DOCKER
        docker exec #{container} bash -c 'find #{USER_SCRIPT_DIR} -type f -exec chmod +x {} +' && \
        docker exec -w #{SHARED_VOL} #{container} #{command}
      DOCKER
    end

    # Attempt command execution with retries
    retries.times do |attempt|
      begin
        # Execute command with timeout protection
        Timeout.timeout(timeout) do
          # Execute the command and capture output
          stdout, stderr, status = Open3.capture3(system_command)
          
          # Process the execution result
          if block_given?
            # Use custom output handling if block is provided
            return yield(stdout, stderr, status)
          elsif status.success?
            # Return success message with output
            return "#{success}: #{stdout}"
          else
            # Raise error on last attempt if command failed
            raise StandardError, "Error occurred: #{stderr}" if attempt == retries - 1
          end
        end
      rescue Timeout::Error => e
        # Handle timeout error
        raise e if attempt == retries - 1
        sleep(retry_delay * (attempt + 1))  # Exponential backoff
      rescue StandardError => e
        # Handle other errors
        raise e if attempt == retries - 1
        sleep(retry_delay * (attempt + 1))  # Exponential backoff
      end
    end
  rescue StandardError => e
    # Return error message if all attempts fail
    "Error occurred: #{e.message}"
  end

  def execute_with_fallback(system_command)
    begin
      # Try PTY first for better output handling
      execute_with_pty(system_command)
    rescue StandardError
      execute_with_open3(system_command)
    end
  end

  def execute_with_pty(system_command)
    output = { stdout: "", stderr: "", status: nil }
    
    PTY.spawn(system_command) do |stdout, stdin, pid|
      begin
        stdout.each { |line| output[:stdout] += line }
      rescue Errno::EIO
        # Expected behavior when PTY closes
      end
      Process.wait(pid)
      output[:status] = $?.exitstatus
    end
    
    output
  end

  def execute_with_open3(system_command)
    stdout, stderr, status = Open3.capture3(system_command)
    { stdout: stdout, stderr: stderr, status: status.exitstatus }
  end

  def json2html(hash, iteration: 0, exclude_empty: true, mathjax: false)
    return hash.to_s unless hash.is_a?(Hash)

    iteration += 1
    output = +""

    if hash.key?("message")
      message = hash["message"]
      output += StringUtils.markdown_to_html(message, mathjax: mathjax)
      output += "<hr />"
      hash = hash.reject { |k, _| k == "message" }
    end

    hash.each do |key, value|
      next if exclude_empty && (value.nil? || value == "" || (value.is_a?(Array) && value.empty?))

      key = snake2cap(key)
      data_key = key.downcase

      if key.downcase == "context"
        output += "<div class='json-item context' data-depth='#{iteration}' data-key='context'>"
        output += "<div class='json-header' onclick='toggleItem(this)'>"
        output += "<span>Context</span>"
        output += " <i class='fas fa-chevron-down float-right'></i> <span class='toggle-text'>click to toggle</span>"
        output += "</div>"
        output += "<div class='json-content' style='margin-left:1em'>"
        output += json2html(value, iteration: iteration, exclude_empty: exclude_empty, mathjax: mathjax)
        output += "</div></div>"
      else
        case value
        when Hash
          output += "<div class='json-item' data-depth='#{iteration}' data-key='#{data_key}'>"
          output += "<div class='json-header' onclick='toggleItem(this)'>"
          output += "<span>#{key}</span>"
          output += " <i class='fas fa-chevron-down float-right'></i> <span class='toggle-text'>Close</span>"
          output += "</div>"
          output += "<div class='json-content' style='margin-left:1em'>"
          output += json2html(value, iteration: iteration, exclude_empty: exclude_empty, mathjax: mathjax)
          output += "</div></div>"
        when Array
          if value.all? { |v| v.is_a?(String) }
            output += "<div class='json-item' data-depth='#{iteration}' data-key='#{data_key}'>"
            output += "<span>#{key}: [#{value.join(', ')}]</span>"
            output += "</div>"
          else
            output += "<div class='json-item' data-depth='#{iteration}' data-key='#{data_key}'>"
            output += "<div class='json-header' onclick='toggleItem(this)'>"
            output += "<span>#{key}</span>"
            output += " <i class='fas fa-chevron-down float-right'></i> <span class='toggle-text'>Close</span>"
            output += "</div>"
            output += "<div class='json-content' style='margin-left:1em'>"
            output += "<ul class='no-bullets'>"
            value.each do |v|
              output += if v.is_a?(String)
                          v = StringUtils.markdown_to_html(v, mathjax: mathjax)
                          "<li>#{v}</li>"
                        else
                          "<li>#{json2html(v, iteration: iteration, exclude_empty: exclude_empty, mathjax: mathjax)}</li>"
                        end
            end
            output += "</ul>"
            output += "</div></div>"
          end
        else
          # Check if the value is a single paragraph
          if value.is_a?(String) && !value.include?("\n")
            output += "<div class='json-item' data-depth='#{iteration}' data-key='#{data_key}'>"
            output += "<span>#{key}: </span>"
            output += "<span>#{value}</span>"
            output += "</div>"
          else
            output += "<div class='json-item' data-depth='#{iteration}' data-key='#{data_key}'>"
            output += "<span>#{key}: </span>"
            value = StringUtils.markdown_to_html(value, mathjax: mathjax)
            output += "<span>#{value}</span>"
            output += "</div>"
          end
        end
      end
    end

    "<div class='json-container'>#{output}</div>"
  end

  def send_code(code:, command:, extension:, success: "The code has been executed successfully", max_retries: 3, retry_delay: 1.5, keep_file: true)
    retries = 0
    last_error = nil

    begin
      # Set appropriate paths based on environment
      if IN_CONTAINER
        data_dir = SHARED_VOL
        files_dir = SHARED_VOL
      else
        data_dir = LOCAL_SHARED_VOL
        files_dir = File.expand_path(File.join(Dir.home, "monadic", "data"))
      end

      container = "monadic-chat-python-container"

      # Generate timestamp-based filename
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      filename = "code_#{timestamp}.#{extension}"

      if keep_file
        # Create a permanent file with timestamp-based name
        file_path = File.join(data_dir, filename)
        File.write(file_path, code)
      else
        # Create a temporary file with timestamp-based name
        temp_file = Tempfile.new(["code_#{timestamp}", ".#{extension}"], data_dir)
        temp_file.write(code)
        temp_file.close
        file_path = temp_file.path
      end

      # Get the list of files with their timestamps before execution
      local_files1 = Dir[File.join(files_dir, "*")].map { |file| [file, File.mtime(file)] }

      # Copy the file to the container
      docker_command = <<~DOCKER
        docker cp #{file_path} #{container}:#{SHARED_VOL}
      DOCKER
      stdout, stderr, status = Open3.capture3(docker_command)
      unless status.success?
        raise "Error occurred: #{stderr}"
      end

      # Execute the code in the container
      docker_command = <<~DOCKER
        docker exec -w #{SHARED_VOL} #{container} #{command} /monadic/data/#{File.basename(file_path)}
      DOCKER

      stdout, stderr, status = Open3.capture3(docker_command)

      # wait for the command to finish and status to be available
      sleep 1

      if status.success?
        # Get the list of files after execution
        local_files2 = Dir[File.join(files_dir, "*")].map { |file| [file, File.mtime(file)] }

        # `new_files` contains newly created or updated files (check the timestamp)
        new_files = (local_files2 - local_files1).map(&:first) - [file_path]

        # Prepare the success message with file information
        if !new_files.empty?
          new_files = new_files.map { |file| "/data/" + File.basename(file) }
          output = "#{success}; File(s) generated: #{new_files.join(", ")}"
          output += "; Output: #{stdout}" if stdout.strip.length.positive?
        else
          output = "#{success} (No files generated)"
          output += "; Output: #{stdout}" if stdout.strip.length.positive?
        end

        # Clean up temporary file if keep_file is false
        temp_file.unlink if !keep_file && temp_file

        output
      else
        # Create detailed error information
        last_error = {
          message: stderr,
          type: detect_error_type(stderr),
          code_snippet: code,
          attempt: retries + 1
        }
        raise StandardError, generate_error_suggestions(last_error)
      end
    rescue StandardError => e
      if retries < max_retries
        retries += 1
        sleep(retry_delay)
        retry
      else
        "Error executing code: #{e.message}"
      end
    end
  end

  def detect_error_type(error_message)
    case error_message
    when /SyntaxError/
      "SyntaxError"
    when /ImportError|ModuleNotFoundError/
      "ImportError"
    when /NameError/
      "NameError"
    when /TypeError/
      "TypeError"
    when /ValueError/
      "ValueError"
    when /IndexError/
      "IndexError"
    when /KeyError/
      "KeyError"
    else
      "UnknownError"
    end
  end

  def generate_error_suggestions(error)
    case error[:type]
    when "SyntaxError"
      "Check the code syntax: verify indentation, matching brackets, and proper statement termination."
    when "ImportError"
      "Required library might be missing. Check if all necessary packages are installed."
    when "NameError"
      "Variable or function might be undefined. Verify all names are properly defined before use."
    when "TypeError"
      "Operation might be performed on incompatible types. Check variable types and operations."
    when "ValueError"
      "Invalid value provided for operation. Verify input values and their formats."
    when "IndexError"
      "Array index out of bounds. Check array lengths and index values."
    when "KeyError"
      "Dictionary key not found. Verify key existence before access."
    else
      "Unexpected error occurred. Review the code logic and implementation."
    end
  end

  def run_code(code: nil, command: nil, extension: nil, success: "The code has been executed successfully")
    return "Error: code, command, and extension are required." if !code || !command || !extension

    send_code(code: code, command: command, extension: extension, success: success)
  end

  def run_script(code: nil, command: nil, extension: nil, success: "The code has been executed successfully")
    # Remove escape characters from the code
    if code
      code = code.gsub(/\\n/) { "\n" }
      code = code.gsub(/\\'/) { "'" }
      code = code.gsub(/\\"/) { '"' }
      code = code.gsub(/\\\\/) { "\\" }
    end

    # Return error message unless all arguments are provided
    return "Error: code, command, and extension are required." if !code || !command || !extension

    send_code(code: code, command: command, extension: extension, success: success)
  end

  def ask_openai(parameters)
    BasicAgent.send_query(parameters)
  end

  def current_time
    Time.now.to_s
  end
end
