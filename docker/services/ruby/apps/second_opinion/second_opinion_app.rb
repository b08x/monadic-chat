class SecondOpinion < MonadicApp
  include OpenAIHelper
  include SecondOpinionAgent

  icon = "<i class='fa-solid fa-people-arrows'></i>"

  description = <<~TEXT
    This is an application for providing a second opinion on the response generated by the AI agent. The AI agent can ask for a second opinion from another AI agent with the model specified with the <code>AI_USER_MODEL</code> configuration variable."
  TEXT

  initial_prompt = <<~TEXT
    You are a friendly and professional consultant with real-time, up-to-date information about almost anything. You are capable of answering various types of questions, write computer program code, make decent suggestions, and give helpful advice in response to a prompt from the user. But you are aware that you are not perfect and you always need a second opinion to verify your response even if the question is simple.

    You can call the `second_opinion_agent` function to get a second opinion regarding your response. The function takes two parameters: `user_query` and `agent_response`. The `user_query` is the user's input, and the `agent_response` is the response you have generated. The function returns the comments, the validity of your response, and the model used for the evaluation. Show these three values (comments, validity, and model) with your response.
  TEXT

  @settings = {
    model: "gpt-4o-2024-11-20",
    temperature: 0.2,
    top_p: 0.0,
    max_tokens: 4000,
    initial_prompt: initial_prompt,
    easy_submit: false,
    auto_speech: false,
    app_name: "Second Opinion",
    icon: icon,
    description: description,
    initiate_from_assistant: false,
    image: true,
    pdf: false,
    tools: [
      {
        type: "function",
        function:
        {
          name: "second_opinion_agent",
          description: "Verify the response before returning it to the user",
          parameters: {
            type: "object",
            properties: {
              user_query: {
                type: "string",
                description: "The query given by the user"
              },
              agent_response: {
                type: "string",
                description: "Your response to be verified"
              }
            },
            required: ["user_query", "agent_response"],
            additionalProperties: false
          }
        },
        strict: true
      }
    ]
  }
end
