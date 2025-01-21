module DeepSeekHelper
  MAX_FUNC_CALLS = 10
  API_ENDPOINT = "https://api.deepseek.com"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 60
  WRITE_TIMEOUT = 60
  MAX_RETRIES = 5
  RETRY_DELAY = 1

  class << self
    attr_reader :cached_models

    @current_mode = nil

    def list_models
      # Return cached models if they exist
      return @cached_models if @cached_models

      api_key = CONFIG["DEEPSEEK_API_KEY"]
      return [] if api_key.nil?

      headers = {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }

      target_uri = "#{API_ENDPOINT}/models"
      http = HTTP.headers(headers)

      begin
        res = http.get(target_uri)

        if res.status.success?
          # Cache the filtered and sorted models
          model_data = JSON.parse(res.body)
          @cached_models = model_data["data"].sort_by do |model|
            model["created"]
          end.reverse.map do |model|
            model["id"]
          end.filter do |model|
            !model.include?("embed")
          end
          @cached_models
        end
      rescue HTTP::Error, HTTP::TimeoutError
        []
      end
    end

    # Method to manually clear the cache if needed
    def clear_models_cache
      @cached_models = nil
    end
  end

  def api_request(role, session, call_depth: 0, &block)

    num_retrial = 0

    # session[:messages].delete_if do |msg|
    #   msg["role"] == "assistant" && msg["content"].to_s == ""
    # end

    begin
      api_key = CONFIG["DEEPSEEK_API_KEY"]
      raise if api_key.nil?
    rescue StandardError
      pp error_message = "ERROR: DEEPSEEK_API_KEY not found. Please set the DEEPSEEK_API_KEY environment variable in the ~/monadic/config/env file."
      res = { "type" => "error", "content" => error_message }
      block&.call res
      return []
    end

    obj = session[:parameters]
    app = obj["app_name"]

    max_tokens = obj["max_tokens"]&.to_i
    temperature = obj["temperature"].to_f
    context_size = obj["context_size"].to_i
    request_id = SecureRandom.hex(4)

    if role != "tool"
      message = obj["message"].to_s

      html = if message != ""
               markdown_to_html(message)
             else
               message
             end

      if message != "" && role == "user"
        res = { "type" => "user",
                "content" => {
                  "mid" => request_id,
                  "role" => role,
                  "text" => message,
                  "html" => html,
                  "lang" => detect_language(obj["message"])
                } }
        block&.call res
        session[:messages] << res["content"]
      end
    end

    session[:messages].each { |msg| msg["active"] = false }
    context = [session[:messages].first]
    if session[:messages].length > 1
      context += session[:messages][1..].last(context_size + 1)
    end
    context.each { |msg| msg["active"] = true }

    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{api_key}"
    }

    body = {
      "model" => obj["model"],
      "stream" => true
    }

    body["max_tokens"] = max_tokens if max_tokens

    body["temperature"] = temperature

    body["messages"] = context.compact.map do |msg|
      { "role" => msg["role"], "content" => msg["text"] }
    end

    if settings["tools"]
      body["tools"] = settings["tools"]
      body["tool_choice"] = "auto"
    else
      body.delete("tool_choice")
    end

    if role == "tool"
      body["messages"] += obj["function_returns"]
    elsif role == "user"
      body["messages"].last["content"] += "\n\n" + settings["prompt_suffix"] if settings["prompt_suffix"]
    end

    if obj["model"].include?("reasoner")
      body.delete("temperature")
      body.delete("tool_choice")
      body.delete("tools")
      body.delete("top_p")
      body.delete("presence_penalty")
      body.delete("frequency_penalty")


      # remove the text from the beginning of the message to "---" from the previous messages
      body["messages"] = body["messages"].map do |msg|
        msg["content"] = msg["content"].sub(/---\n\n/, "")
        msg
      end


      # concatenate previous messages into one and put it to the only message with the role "user"
      # the single message holds all the messages with the roles "user", "assistant", and "system"
      # an example of the format:
      #
      #  SYSTEM: SYSTEM MESSAGE
      #  USER: USER MESSAGE
      #  ASSISTANT: ASSISTANT MESSAGE
      #  USER: USER MESSAGE
      #  ...

      # concatenated_messages = body["messages"].map do |msg|
      #   "#{msg['role'].upcase}: #{msg['content']}"
      # end
      # body["messages"] = [{ "role" => "user", "content" => concatenated_messages.join("\n") }]
    end

    target_uri = "#{API_ENDPOINT}/chat/completions"
    headers["Accept"] = "text/event-stream"
    http = HTTP.headers(headers)

    MAX_RETRIES.times do
      res = http.timeout(connect: OPEN_TIMEOUT,
                         write: WRITE_TIMEOUT,
                         read: READ_TIMEOUT).post(target_uri, json: body)
      if res.status.success?
        break
      end

      sleep RETRY_DELAY
    end

    unless res.status.success?
      error_report = JSON.parse(res.body)
      pp error_report
      res = { "type" => "error", "content" => "API ERROR: #{error_report}" }
      block&.call res
      return [res]
    end

    process_json_data(app, session, res.body, call_depth, &block)
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

  def process_json_data(app, session, body, call_depth, &block)
    @current_mode = nil

    buffer = String.new.force_encoding("UTF-8")
    texts = {}
    tools = {}
    finish_reason = nil
    partial_json = nil
    first_message = true

    body.each do |chunk|
      begin
        if buffer.valid_encoding? == false
          buffer << chunk
          next
        end

        if !chunk.force_encoding("UTF-8").valid_encoding?
          chunk = chunk.encode("UTF-8", "UTF-8", invalid: :replace, undef: :replace)
        end

        # Process partial JSON if exists
        if partial_json
          buffer = partial_json + chunk
        else
          buffer << chunk
        end

        # Try to extract complete JSON messages
        messages = extract_complete_messages(buffer)
        
        if messages.empty?
          # If no complete messages found, retain buffer and wait for next chunk
          partial_json = buffer
          next
        else
          # If the last message is incomplete, keep it for next processing
          last_message = messages.pop if !is_complete_json(messages.last)
          partial_json = last_message
          
          messages.each do |msg|
            begin
              data_content = msg.match(/data: (\{.*\})/m)
              return unless data_content && data_content[1]

              json = JSON.parse(data_content[1])

              reasoning_content = ""
              
              # Process finish reason
              finish_reason = json.dig("choices", 0, "finish_reason")
              case finish_reason
              when "length"
                finish_reason = "length"
              when "stop"
                finish_reason = "stop"
              when "tool_calls"
                finish_reason = "function_call"
              else
                finish_reason = nil
              end

              # Process text content
              if json.dig("choices", 0, "delta")
                delta = json["choices"][0]["delta"]
                
                if delta["reasoning_content"]
                  id = json["id"]
                  texts[id] ||= json
                  choice = texts[id]["choices"][0]
                  choice["message"] ||= delta.dup
                  fragment = delta["reasoning_content"].to_s

                  if @current_mode != "reasoning"
                    choice["message"]["content"] = <<~THINKING
                      <div data-title='Thinking' class='toggle'><div class='toggle-open'>
                    THINKING
                    @current_mode = "reasoning"
                  end

                  choice["message"]["content"] << fragment

                  res = {
                    "type" => "fragment",
                    "content" => fragment
                  }
                  block&.call res

                  texts[id]["choices"][0].delete("delta")

                elsif delta["content"]
                  id = json["id"]
                  texts[id] ||= json
                  choice = texts[id]["choices"][0]
                  choice["message"] ||= delta.dup
                  choice["message"]["content"] ||= ""

                  if @current_mode == "reasoning"
                    div_close = "</div></div>\n\n---\n\n"
                    choice["message"]["content"] << div_close
                    res = {
                      "type" => "fragment",
                      "content" => div_close
                    }
                    block&.call res
                    @current_mode = nil
                  end

                  fragment = delta["content"].to_s
                  choice["message"]["content"] << fragment

                  res = {
                    "type" => "fragment",
                    "content" => fragment
                  }
                  block&.call res

                  texts[id]["choices"][0].delete("delta")
                end

                # Process tool calls
                if delta["tool_calls"]
                  res = { "type" => "wait", "content" => "<i class='fas fa-cogs'></i> CALLING FUNCTIONS" }
                  block&.call res

                  tid = json.dig("choices", 0, "delta", "tool_calls", 0, "id")

                  if tid
                    tools[tid] = json
                    tools[tid]["choices"][0]["message"] ||= tools[tid]["choices"][0]["delta"].dup
                    tools[tid]["choices"][0].delete("delta")
                  else
                    new_tool_call = json.dig("choices", 0, "delta", "tool_calls", 0)
                    existing_tool_call = tools.values.last.dig("choices", 0, "message")
                    existing_tool_call["tool_calls"][0]["function"]["arguments"] << new_tool_call["function"]["arguments"]
                  end
                end
              end
            rescue JSON::ParserError => e
              pp "JSON parse error in message: #{e.message}"
            end
          end
        end

        buffer = String.new

      rescue StandardError => e
        pp e.message
        pp e.backtrace
        next
      end
    end

    # Process the final results
    result = texts.empty? ? nil : texts.first[1]

    if tools.any?
      # Handle tool/function calls
      tools = tools.first[1].dig("choices", 0, "message", "tool_calls")
      context = []
      res = {
        "role" => "assistant",
        "content" => "The AI model is calling functions to process the data."
      }
      res["tool_calls"] = tools.map do |tool|
        {
          "id" => tool["id"],
          "type" => "function",
          "function" => tool["function"]
        }
      end
      context << res

      # Check for maximum function call depth
      call_depth += 1
      if call_depth > MAX_FUNC_CALLS
        return [{ "type" => "error", "content" => "ERROR: Call depth exceeded" }]
      end

      # Process function calls and get new results
      new_results = process_functions(app, session, tools, context, call_depth, &block)

      if new_results
        new_results
      elsif result
        [result]
      end
    elsif result
      # Return final result with finish reason
      res = { "type" => "message", "content" => "DONE", "finish_reason" => finish_reason }
      block&.call res
      result["choices"][0]["finish_reason"] = finish_reason
      [result]
    else
      # Return done message if no result
      res = { "type" => "message", "content" => "DONE" }
      block&.call res
      [res]
    end
  end

  private

  def extract_complete_messages(buffer)
    # Split by data message boundary pattern
    messages = buffer.split(/(?<=\n\n)(?=data: )/)
    messages.select { |msg| msg.start_with?('data: ') }
  end

  def is_complete_json(message)
    return false unless message.start_with?('data: ')
    
    begin
      data_content = message.match(/data: (\{.*\})/m)
      return false unless data_content && data_content[1]
      
      json = JSON.parse(data_content[1])
      
      # Check if JSON structure meets expectations
      return false unless json["choices"]&.first&.key?("delta")
      
      true
    rescue JSON::ParserError
      false
    end
  end

  def process_functions(app, session, tools, context, call_depth, &block)
    obj = session[:parameters]
    tools.each do |tool_call|
      function_call = tool_call["function"]
      function_name = function_call["name"]

      begin
        escaped = function_call["arguments"]
        argument_hash = JSON.parse(escaped)
      rescue JSON::ParserError
        argument_hash = {}
      end

      converted = {}
      argument_hash.each_with_object(converted) do |(k, v), memo|
        memo[k.to_sym] = v
        memo
      end

      begin
        function_return = APPS[app].send(function_name.to_sym, **converted)
      rescue StandardError => e
        function_return = "ERROR: #{e.message}"
      end

      context << {
        role: "tool",
        tool_call_id: tool_call["id"],
        name: function_name,
        content: function_return.to_s
      }
    end

    obj["function_returns"] = context

    sleep RETRY_DELAY
    api_request("tool", session, call_depth: call_depth, &block)
  end
end
