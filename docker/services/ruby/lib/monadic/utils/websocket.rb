# frozen_string_literal: true

module WebSocketHelper
  # Handle websocket connection

  # check if the total tokens of past messages is less than max_tokens in obj
  # token count is calculated using tiktoken_ruby gem
  def check_past_messages(obj)
    # filter out any messages of type "search"
    messages = session[:messages].filter { |m| m["type"] != "search" }

    res = false
    max_tokens = obj["max_tokens"].to_i
    context_size = obj["context_size"].to_i
    tokenizer_available = true

    # gpt-4o => o200k_base;
    model_name = /gpt-4o/ =~ obj["model"] ? "gpt-4o" : "gpt-3.5-turbo"

    encoding_name = MonadicApp::TOKENIZER.get_encoding_name(model_name)

    begin
      # Calculate token count for each message and mark as active if not already calculated
      messages.each do |m|
        m["tokens"] ||= MonadicApp::TOKENIZER.count_tokens(m["text"], model_name)
        m["active"] = true
      end

      # Filter active messages and calculate total token count
      active_messages = messages.select { |m| m["active"] }.reverse
      total_tokens = active_messages.sum { |m| m["tokens"] || 0 }

      # Remove oldest messages until total token count and message count are within limits
      until active_messages.empty? || (total_tokens <= max_tokens && active_messages.size <= context_size)
        last_message = active_messages.pop
        last_message["active"] = false
        total_tokens -= last_message["tokens"] || 0
        res = true
      end

      # Calculate total token counts for different roles
      count_total_system_tokens = messages.filter { |m| m["role"] == "system" }.sum { |m| m["tokens"] || 0 }
      count_total_input_tokens = messages.filter { |m| m["role"] == "user" }.sum { |m| m["tokens"] || 0 }
      count_total_output_tokens = messages.filter { |m| m["role"] == "assistant" }.sum { |m| m["tokens"] || 0 }
      count_active_tokens = active_messages.sum { |m| m["tokens"] || 0 }
      count_all_tokens = messages.sum { |m| m["tokens"] || 0 }
    rescue StandardError => e
      pp e.message
      pp e.backtrace
      pp e.inspect
      tokenizer_available = false
    end

    # Return information about the state of the messages array
    res = { changed: res,
            count_total_system_tokens: count_total_system_tokens,
            count_total_input_tokens: count_total_input_tokens,
            count_total_output_tokens: count_total_output_tokens,
            count_total_active_tokens: count_active_tokens,
            count_all_tokens: count_all_tokens,
            count_messages: messages.size,
            count_active_messages: active_messages.size,
            encoding_name: encoding_name }
    res[:error] = "Error: Token count not available" unless tokenizer_available
    res
  end

  def websocket_handler(env)
    EventMachine.run do
      queue = Queue.new
      thread = nil
      sid = nil
      @channel = EventMachine::Channel.new

      ws = Faye::WebSocket.new(env, nil, { ping: 15 })
      ws.on :open do
        sid = @channel.subscribe { |obj| ws.send(obj) }
      end

      ws.on :message do |event|
        obj = JSON.parse(event.data)
        msg = obj["message"] || ""

        case msg
        when "TTS"
          text = obj["text"]
          voice = obj["voice"]
          speed = obj["speed"]
          response_format = obj["response_format"]
          model = obj["model"]
          res_hash = tts_api_request(text, voice, speed, response_format, model)
          @channel.push(res_hash.to_json)
        when "TTS_STREAM"
          thread&.join
          text = obj["text"]
          voice = obj["voice"]
          speed = obj["speed"]
          response_format = obj["response_format"]
          model = obj["model"]
          tts_api_request(text, voice, speed, response_format, model) do |fragment|
            @channel.push(fragment.to_json)
          end
        when "CANCEL"
          thread&.kill
          thread = nil
          queue.clear
          @channel.push({ "type" => "cancel" }.to_json)
        when "PDF_TITLES"
          ws.send({
            "type" => "pdf_titles",
            "content" => list_pdf_titles
          }.to_json)
        when "DELETE_PDF"
          title = obj["contents"]
          res = EMBEDDINGS_DB.delete_by_title(title)
          if res
            ws.send({ "type" => "pdf_deleted", "res" => "success", "content" => "<b>#{title}</b> deleted successfully" }.to_json)
          else
            ws.send({ "type" => "pdf_deleted", "res" => "failure", "content" => "Error deleting <b>#{title}</b>" }.to_json)
          end
        when "CHECK_TOKEN"
          if CONFIG["ERROR"].to_s == "true"
            ws.send({ "type" => "error", "content" => "Error reading <code>~/monadic/data/.env</code>" }.to_json)
          else
            token = CONFIG["OPENAI_API_KEY"]

            res = check_api_key(token) if token

            if token && res.is_a?(Hash) && res.key?("type")
              if res["type"] == "error"
                ws.send({ "type" => "token_not_verified", "token" => "", "content" => "" }.to_json)
              else
                ws.send({ "type" => "token_verified",
                          "token" => token, "content" => res["content"],
                          "models" => res["models"],
                          "ai_user_initial_prompt" => MonadicApp::AI_USER_INITIAL_PROMPT }.to_json)
              end
            else
              ws.send({ "type" => "token_not_verified", "token" => "", "content" => "" }.to_json)
            end
          end
        when "PING"
          @channel.push({ "type" => "pong" }.to_json)
        when "RESET"
          session[:messages].clear
          session[:parameters].clear
          session[:error] = nil
          session[:obj] = nil
        when "LOAD"
          if session[:error]
            ws.send({ "type" => "error", "content" => session[:error] }.to_json)
            session[:error] = nil
          end
          apps = {}
          APPS.each do |k, v|
            apps[k] = {}
            v.settings.each do |p, m|
              apps[k][p] = m ? m.to_s : nil
            end
            v.api_key = settings.api_key
          end

          # Filter messages only once and store in filtered_messages
          filtered_messages = session[:messages].filter { |m| m["type"] != "search" }

          # Use filtered_messages for pushing past messages
          @channel.push({ "type" => "apps", "content" => apps, "version" => session[:version], "docker" => session[:docker] }.to_json) unless apps.empty?
          @channel.push({ "type" => "parameters", "content" => session[:parameters] }.to_json) unless session[:parameters].empty?
          @channel.push({ "type" => "past_messages", "content" => filtered_messages }.to_json) unless session[:messages].empty? 

          past_messages_data = check_past_messages(session[:parameters])

          # Reuse filtered_messages for change_status
          @channel.push({ "type" => "change_status", "content" => filtered_messages }.to_json) if past_messages_data[:changed] 
          @channel.push({ "type" => "info", "content" => past_messages_data }.to_json)
        when "DELETE"
          session[:messages].delete_if { |m| m["mid"] == obj["mid"] }
          past_messages_data = check_past_messages(session[:parameters])

          # Filter messages only once and store in filtered_messages
          filtered_messages = session[:messages].filter { |m| m["type"] != "search" }

          # Reuse filtered_messages for change_status
          @channel.push({ "type" => "change_status", "content" => filtered_messages }.to_json) if past_messages_data[:changed] 
          @channel.push({ "type" => "info", "content" => past_messages_data }.to_json)
        when "AI_USER_QUERY"
          thread&.join

          aiu_buffer = []

          reversed_messages = session[:messages].map do |m|
            m["role"] = m["role"] == "assistant" ? "user" : "assistant"
            if obj["contents"]["params"]["monadic"].to_s == "true"
              begin
                parsed = JSON.parse(m["text"])
                m["text"] = parsed["message"] || parsed["response"]
              rescue JSON::ParserError
                # do nothing
              end
            end
            m
          end

          # copy obj["contents"]["params"] to parameters_modified
          parameters_modified = obj["contents"]["params"].dup
          parameters_modified.delete("tools")
          message_text = reversed_messages.pop["text"]

          parameters_modified["message"] = message_text

          # code to use the OpenAI mode for AI User
          api_request = method(:openai_api_request)
          parameters_modified["model"] = CONFIG["AI_USER_MODEL"] || "gpt-4o-mini"

          mini_session = {
            parameters: parameters_modified,
            messages: reversed_messages
          }

          mini_session[:parameters]["initial_prompt"] = mini_session[:parameters]["ai_user_initial_prompt"]
          mini_session[:parameters]["monadic"] = false

          responses = api_request.call("user", mini_session) do |fragment|
            if fragment["type"] == "error"
              @channel.push({ "type" => "error", "content" => "E1:#{fragment}" }.to_json)
            elsif fragment["type"] == "fragment"
              text = fragment["content"]
              @channel.push({ "type" => "ai_user", "content" => text }.to_json)
              aiu_buffer << text unless text.empty? || text == "DONE"
            end
          end

          ai_user_response = aiu_buffer.join
          @channel.push({ "type" => "ai_user_finished", "content" => ai_user_response }.to_json)
        when "HTML"
          thread&.join
          until queue.empty?
            last_one = queue.shift
            begin
              content = last_one["choices"][0]

              text = content["text"] || content["message"]["content"]

              type_continue = "Press <button class='btn btn-secondary btn-sm contBtn'>continue</button> to get more results\n"
              code_truncated = "[CODE BLOCK TRUNCATED]"

              if content["finish_reason"] && content["finish_reason"] == "length"
                if text.scan(/(?:\A|\n)```/m).size.odd?
                  text += "\n```\n\n> #{type_continue}\n#{code_truncated}"
                else
                  text += "\n\n> #{type_continue}"
                end
              end

              if content["finish_reason"] && content["finish_reason"] == "safety"
                @channel.push({ "type" => "error", "content" => "The API stopped responding because of safety reasons" }.to_json)
              end

              html = if session["parameters"]["monadic"]
                       APPS[session["parameters"]["app_name"]].monadic_html(text)
                     else
                       markdown_to_html(text)
                     end

              if session["parameters"]["response_suffix"]
                html += "\n\n" + session["parameters"]["response_suffix"]
              end

              new_data = { "mid" => SecureRandom.hex(4), "role" => "assistant", "text" => text, "html" => html, "lang" => detect_language(text), "active" => true } # detect_language is called only once here

              @channel.push({
                "type" => "html",
                "content" => new_data
              }.to_json)

              session[:messages] << new_data
              messages = session[:messages].filter { |m| m["type"] != "search" }
              past_messages_data = check_past_messages(session[:parameters])

              @channel.push({ "type" => "change_status", "content" => messages }.to_json) if past_messages_data[:changed]
              @channel.push({ "type" => "info", "content" => past_messages_data }.to_json)
            rescue StandardError => e
              pp queue
              pp e.message
              pp e.backtrace
              @channel.push({ "type" => "error", "content" => "Something went wrong" }.to_json)
            end
          end
        when "SYSTEM_PROMPT"
          text = obj["content"] || ""
          new_data = { "mid" => SecureRandom.hex(4),
                       "role" => "system",
                       "text" => text,
                       "html" => markdown_to_html(text),
                       "lang" => detect_language(text), # detect_language is called only once here
                       "active" => true }
          # Initial prompt is added to messages but not shown as the first message
          # @channel.push({ "type" => "html", "content" => new_data }.to_json)
          session[:messages] << new_data

        when "SAMPLE"
          text = obj["content"]
          images = obj["images"]
          new_data = { "mid" => SecureRandom.hex(4),
                       "role" => obj["role"],
                       "text" => text,
                       "html" => markdown_to_html(text),
                       "lang" => detect_language(text),
                       "active" => true }
          new_data["images"] = images if images

          @channel.push({ "type" => "html", "content" => new_data }.to_json)
          session[:messages] << new_data
        when "AUDIO"
          if obj["content"].nil?
            @channel.push({ "type" => "error", "content" => "Voice input is empty" }.to_json)
          else
            blob = Base64.decode64(obj["content"])
            res = whisper_api_request(blob, obj["format"], obj["lang_code"])
            if res["text"] && res["text"] == ""
              @channel.push({ "type" => "error", "content" => "The text input is empty" }.to_json)
            elsif res["type"] && res["type"] == "error"
              @channel.push({ "type" => "error", "content" => res["content"] }.to_json)
            else
              # get mean score of "avg_logprob" of res["content"]["segments"]
              avg_logprobs = res["segments"].map { |s| s["avg_logprob"].to_f }
              logprob = Math.exp(avg_logprobs.sum / avg_logprobs.size).round(2)
              @channel.push({
                "type" => "whisper",
                "content" => res["text"],
                "logprob" => logprob
              }.to_json)
            end
          end
        else # fragment
          session[:parameters].merge! obj

          if obj["auto_speech"]
            voice = obj["tts_voice"]
            speed = obj["tts_speed"]
            response_format = "mp3"
            model = "tts-1"
          end

          thread = Thread.new do
            buffer = []
            cutoff = false

            app_name = obj["app_name"]
            app_obj = APPS[app_name]

            responses = app_obj.api_request("user", session) do |fragment|
              if fragment["type"] == "error"
                @channel.push({ "type" => "error", "content" => fragment }.to_json)
                break
              elsif fragment["type"] == "fragment"
                text = fragment["content"]
                buffer << text unless text.empty? || text == "DONE"
                ps = PragmaticSegmenter::Segmenter.new(text: buffer.join)
                segments = ps.segment
                if !cutoff && segments.size > 1
                  candidate = segments.first
                  splitted = candidate.split("---")
                  if splitted.empty?
                    cutoff = true
                  end

                  if obj["auto_speech"] && !cutoff && !obj["monadic"]
                    text = splitted[0] || ""
                    if text != "" && candidate != ""
                      res_hash = tts_api_request(text, voice, speed, response_format, model)
                      @channel.push(res_hash.to_json)
                    end
                  end

                  buffer = segments[1..]
                end
              end
              @channel.push(fragment.to_json)
              sleep 0.01
            end

            Thread.exit if !responses || responses.empty?

            if obj["auto_speech"] && !cutoff && !obj["monadic"]
              text = buffer.join
              res_hash = tts_api_request(text, voice, speed, response_format, model)
              @channel.push(res_hash.to_json)
            end

            responses.each do |response|
              # if response is not a hash, skip with error message
              unless response.is_a?(Hash)
                pp response
                next
              end

              if response.key?("type") && response["type"] == "error"
                content = response.dig("choices", 0, "message", "content")
                @channel.push({ "type" => "error", "content" => response.to_s }.to_json)
              else
                content = response.dig("choices", 0, "message", "content").gsub(%r{\bsandbox:/}, "/")
                content = content.gsub(%r{^/mnt/}, "/")

                response.dig("choices", 0, "message")["content"] = content

                if obj["auto_speech"] && obj["monadic"]
                  message = JSON.parse(content)["message"]
                  res_hash = tts_api_request(message, voice, speed, response_format, model)
                  @channel.push(res_hash.to_json)
                end

                queue.push(response)
              end
            end
          end
        end
        end

      ws.on :close do |event|
        pp [:close, event.code, event.reason]
        ws = nil
        @channel.unsubscribe(sid)
      end

      ws.rack_response
    end
  rescue StandardError => e
    # show the details of the error on the console
    puts e.inspect
    puts e.backtrace
  end
end
