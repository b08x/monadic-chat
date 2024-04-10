# frozen_string_literal: false

class Claude < MonadicApp
  include UtilitiesHelper

  API_ENDPOINT = "https://api.anthropic.com/v1"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 60
  WRITE_TIMEOUT = 60
  MAX_RETRIES = 5
  RETRY_DELAY = 1
  
  def icon
    "<i class='fa-solid fa-a'></i>"
  end

  def description
    "This app accesses the Anthropic API to answer questions about a wide range of topics."
  end

  def initial_prompt
    text = <<~TEXT
      You are a friendly and professional consultant with real-time, up-to-date information about almost anything. You are able to answer various types of questions, write computer program code, make decent suggestions, and give helpful advice in response to a prompt from the user. If the prompt is not clear enough, ask the user to rephrase it. Use the same language as the user and insert an emoji that you deem appropriate for the user's input at the beginning of your response.
    TEXT
    text.strip
  end

  def settings
    {
      "app_name": "Talk to Anthropic Claude",
      "max_tokens": 2000,
      "context_size": 20,
      "temperature": 1.0,
      "initial_prompt": initial_prompt,
      "description": description,
      "icon": icon,
      "easy_submit": false,
      "auto_speech": false,
      "initiate_from_assistant": false,
      "tools": [
        {
          "name": "fetch_web_content",
          "description": "Fetch the content of the web page of the given URL and return it.",
          "input_schema": {
            "type": "object",
            "properties": {
              "url": {
                "type": "string",
                "description": "URL of the web page."
              }
            },
            "required": ["url"]
          }
        }
      ]
    }
  end

  def fetch_web_content(url: "")
    selenium_job(url: url)
  end

  def process_json_data(app, session, body, call_depth, &block)
    obj = session[:parameters]

    buffer = ""
    texts = []

    if body.respond_to?(:each)
      body.each do |chunk|
        break if /\Rdata: [DONE]\R/ =~ chunk

        buffer << chunk
        scanner = StringScanner.new(buffer)
        pattern = /data: (\{.*?\})(?=\n|\z)/
        until scanner.eos?
          matched = scanner.scan_until(pattern)
          if matched
            json_data = matched.match(pattern)[1]
            begin
              json = JSON.parse(json_data)

              if json.dig('delta', 'text')
                # Merge text fragments based on 'id'
                fragment = json.dig('delta', 'text').to_s
                texts << fragment
                next if !fragment || fragment == ""

                res = { "type" => "fragment", "content" => fragment }
                block&.call res
              end

            rescue JSON::ParserError
              # if the JSON parsing fails, the next chunk should be appended to the buffer
              # and the loop should continue to the next iteration
            end

          else
            buffer = scanner.rest
            break
          end
        end
      end
    end

    result = texts.empty? ? nil : texts

    if result
      res = { "type" => "message", "content" => "DONE" }
      block&.call res
      [{"choices" => [{"message" => {"content" => result.join("")}}]}]
    else
      res = { "type" => "message", "content" => "DONE" }
      block&.call res
      [{"choices" => [{"message" => {"content" => ""}}]}]
    end
  end

  def api_request(role, session, call_depth: 0, &block)
    num_retrial = 0

    begin
      api_key = nil
      model = nil
      if File.file?("/.dockerenv")
        File.read("/monadic/data/.env").split("\n").each do |line|
          api_key = line.split("=").last if line.start_with?("ANTHROPIC_API_KEY")
          model = line.split("=").last if line.start_with?("ANTHROPIC_MODEL")
        end
      else
        File.read("#{Dir.home}/monadic/data/.env").split("\n").each do |line|
          api_key = line.split("=").last if line.start_with?("ANTHROPIC_API_KEY")
          model = line.split("=").last if line.start_with?("ANTHROPIC_MODEL")
        end
      end
      raise if api_key.nil? || model.nil?
    rescue StandardError
      puts "ERROR: ANTHROPIC_API_KEY or ANTHROPIC_MODEL not found."
      exit
    end

    # Get the parameters from the session
    obj = session[:parameters]
    app = obj["app_name"]

    # Get the parameters from the session
    initial_prompt = obj["initial_prompt"].gsub("{{DATE}}", Time.now.strftime("%Y-%m-%d"))
    temperature = obj["temperature"].to_f

    max_tokens = obj["max_tokens"].to_i
    context_size = obj["context_size"].to_i
    request_id = SecureRandom.hex(4)

    message = obj["message"].to_s

    # If the app is monadic, the message is passed through the monadic_map function
    if obj["monadic"].to_s == "true" && message != ""
      message = monadic_unit(message) if message != ""
      html = markdown_to_html(obj["message"]) if message != ""
    elsif message != ""
      html = markdown_to_html(message)
    end

    if message != "" && role == "user"
      res = { "type" => "user",
              "content" => {
                "mid" => request_id,
                "text" => obj["message"],
                "html" => html,
                "lang" => detect_language(obj["message"])
              }
      }
      res["image"] = obj["image"] if obj["image"]
      block&.call res
    end

    # If the role is "user", the message is added to the session
    if message != "" && role == "user"
      res = { "mid" => request_id,
              "role" => role,
              "text" => message,
              "html" => markdown_to_html(message),
              "lang" => detect_language(message),
              "active" => true,
      }
      if obj["image"]
        res["image"] = obj["image"]
      end
      session[:messages] << res
    end

    # Old messages in the session are set to inactive
    # and set active messages are added to the context
    if session[:messages].empty?
      session[:messages] << { "role" => "user", "text" => "Hi, there!"}
    end
    session[:messages].each { |msg| msg["active"] = false }
    context = session[:messages].last(context_size).each { |msg| msg["active"] = true }

    # Set the headers for the API request
    headers = {
      "anthropic-version" => "2023-06-01",
      "anthropic-beta" => "messages-2023-12-15",
      "content-type" => "application/json",
      "x-api-key" => api_key
    }

    # Set the body for the API request
    body = {
      "system" => initial_prompt,
      "temperature" => temperature,
      "model" => model,
      "stream" => true,
      "max_tokens" => max_tokens
    }

    # The context is added to the body
    messages_containing_img = false
    body["messages"] = context.compact.map do |msg|
      message = { "role" => msg["role"], "content" => [ {"type" => "text", "text" => msg["text"]} ] }
      if msg["image"]
        message["content"] << {
          "type" => "image",
          "source" => {
            "type" => "base64",
            "media_type" => msg["image"]["type"],
            "data" => msg["image"]["data"].split(",")[1]
          }
        }
        messages_containing_img = true
      end
      message
    end

    # Call the API
    target_uri = "#{API_ENDPOINT}/messages"
    headers["Accept"] = "text/event-stream"
    http = HTTP.headers(headers)

    res = http.timeout(connect: OPEN_TIMEOUT, write: WRITE_TIMEOUT, read: READ_TIMEOUT).post(target_uri, json: body)

    unless res.status.success?
      error_report = JSON.parse(res.body)["error"]
      res = { "type" => "error", "content" => "API ERROR: #{error_report["message"]}" }
      block&.call res
      return [res]
    end

    # return Array
    return process_json_data(app, session, res.body, call_depth, &block)

  rescue HTTP::Error, HTTP::TimeoutError
    if num_retrial < MAX_RETRIES
      num_retrial += 1
      sleep RETRY_DELAY
      retry
    else
      pp error_message = "The request has timed out."
      res = { "type" => "error", "content" => "HTTP ERROR: #{error_message}" }
      block&.call res
      [res]
    end
  rescue StandardError => e
    pp e.message
    pp e.backtrace
    pp e.inspect
    res = { "type" => "error", "content" => "UNKNOWN ERROR: #{e.message}\n#{e.backtrace}\n#{e.inspect}" }
    block&.call res
    [res]
  end
end