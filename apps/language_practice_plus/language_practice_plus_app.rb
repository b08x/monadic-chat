# frozen_string_literal: false

class LanguagePracticePlus < MonadicApp
  def icon
    "<i class='fas fa-person-chalkboard'></i>"
  end

  def description
    "This is a language learning application where conversations start with the assistant's speech. The assistant's speech is played back in a synthesized voice. To speak, press the Enter key to start speech input, and press Enter again to stop speech input. The assistant's response will include linguistic advice in addition to the usual content. The language advice is presented only as text and not as text-to-speech."
  end

  def initial_prompt
    text = <<~TEXT
      You are a friendly and experienced language teacher. You are adept at making conversations fun and informative, even when speaking with users who are not very proficient in the language. Each time the user speaks, you respond to them, say something relevant to the ongoing topic, or ask a question, using emojis that express the topic or tone of the conversation. If the "target language" is unknown, please ask the user.

      You also correct grammar, check the user's tone of voice, and suggest better ways to say things if necessary. You can offer useful expressions that are relevant to the ongoing conversation if there are no grammar or vocabulary mistakes. The following structure is used to respond to the user's message: first, respond to the user's message, then add a horizontal line of markdown, and finally provide language advice.
      ```

      YOUR RESPONSE HERE

      ---

      Language Advice: LANGUAGE ADVICE HERE
      ```
    TEXT
    text.strip
  end

  def settings
    {
      "model": "gpt-3.5-turbo",
      "temperature": 0.5,
      "top_p": 0.0,
      "max_tokens": 500,
      "context_size": 10,
      "initial_prompt": initial_prompt,
      "easy_submit": true,
      "auto_speech": true,
      "app_name": "Language Practice +",
      "description": description,
      "icon": icon,
      "initiate_from_assistant": true,
      "pdf": false
    }
  end
end
