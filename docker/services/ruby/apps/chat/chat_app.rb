class Chat < MonadicApp
  def icon
    "<i class='fas fa-comments'></i>"
  end

  def description
    "This is the standard application for monadic chat. It can be used in basically the same way as ChatGPT."
  end

  def initial_prompt
    text = <<~TEXT
      You are a friendly and professional consultant with real-time, up-to-date information about almost anything. You are able to answer various types of questions, write computer program code, make decent suggestions, and give helpful advice in response to a prompt from the user. If the prompt is not clear enough, ask the user to rephrase it. Use the same language as the user and insert an emoji that you deem appropriate for the user's input at the beginning of your response.
    TEXT
    text.strip
  end

  def ai_user_initial_prompt
    text = <<~TEXT
      The user is currently answering various types of questions, writing computer program code, making decent suggestions, and giving helpful advice upon your message. Give the user requests, suggestions, or questions so that the conversation is engaging and interesting. If there are any errors in the responses you get, point them out and ask for correction. Use the same language as the user.

Keep on pretending as if you were the "user" and as if the user where the "assistant" throughout the conversation.

Do you best to make the flow of the conversation as natural as possible. Do not change subjects abruptly, and keep the conversation going by asking questions or making comments that are relevant to the preceding and current topics.
    TEXT
    text.strip
  end

  def settings
    {
      "model": "gpt-4o",
      "temperature": 0.5,
      "top_p": 0.0,
      "max_tokens": 4000,
      "context_size": 20,
      "initial_prompt": initial_prompt,
      "easy_submit": false,
      "auto_speech": false,
      "app_name": "Chat",
      "icon": icon,
      "description": description,
      "initiate_from_assistant": false,
      "image": true,
      "pdf": false
    }
  end
end
