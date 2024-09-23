# Basic Apps

Currently, the following basic apps are available. You can select any of the basic apps and adjust the behavior of the AI agent by changing parameters or rewriting the initial prompt. The adjusted settings can be exported/imported to/from an external JSON file.

## Assistant

### Chat

![Chat app icon](../assets/icons/chat.png ':size=40')

This is a standard chat application. The AI responds to the text input by the user. Emojis corresponding to the content are also displayed.

<details>
<summary>chat_app.rb</summary>

[chat_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/chat/chat_app.rb ':include :type=code')

</details>

### Voice Chat

![Voice Chat app icon](../assets/icons/voice-chat.png ':size=40')

This application allows you to chat using voice, utilizing OpenAI's Whisper API and the browser's speech synthesis API. The initial prompt is the same as the Chat app. A web browser that supports the Text to Speech API, such as Google Chrome or Microsoft Edge, is required.

<details>
<summary>voice_chat_app.rb</summary>

![voice_chat_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/voice_chat/voice_chat_app.rb ':include :type=code')

</details>

### Wikipedia

![Wikipedia app icon](../assets/icons/wikipedia.png ':size=40')

This is basically the same as Chat, but for questions about events that occurred after the language model's cutoff date, which GPT cannot answer, it searches Wikipedia for answers. If the query is in a language other than English, the Wikipedia search is conducted in English, and the results are translated back into the original language.

<details>
<summary>wikipedia_app.rb</summary>

![wikipedia_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/wikipedia/wikipedia_app.rb ':include :type=code')

</details>

### Math Tutor

![Math Tutor app icon](../assets/icons/math.png ':size=40')

This application responds using mathematical notation with [MathJax](https://www.mathjax.org/). While it can display mathematical expressions, its mathematical calculation ability is based on OpenAI's GPT model, which is known to occasionally output incorrect results. Therefore, caution is advised when accuracy is required.

<details>
<summary>math_tutor_app.rb</summary>

![math_tutor_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/math_tutor/math_tutor_app.rb ':include :type=code')

</details>

## Language Learning & Translation

### Language Practice

![Language Practice app icon](../assets/icons/language-practice.png ':size=40')

This is a language learning application where the conversation starts with the assistant's speech. The assistant's speech is played back using speech synthesis. The user starts speech input by pressing the Enter key and ends it by pressing the Enter key again.

<details>
<summary>language_practice_app.rb</summary>

![language_practice_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/language_practice/language_practice_app.rb ':include :type=code')

</details>

### Language Practice Plus

![Language Practice Plus app icon](../assets/icons/language-practice-plus.png ':size=40')

This is a language learning application where the conversation starts with the assistant's speech. The assistant's speech is played back using speech synthesis. The user starts speech input by pressing the Enter key and ends it by pressing the Enter key again. In addition to the usual response, the assistant includes linguistic advice. The linguistic advice is presented only as text, not as speech.

<details>
<summary>language_practice_plus_app.rb</summary>

![language_practice_plus_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/language_practice_plus/language_practice_plus_app.rb ':include :type=code')

</details>

### Translate

![Translate app icon](../assets/icons/translate.png ':size=40')

This app translates the user's input text into another language. First, the assistant asks for the target language. Then, it translates the input text into the specified language. If you want to reflect a specific translation result, enclose the relevant part of the input text in parentheses and specify the translation within the parentheses.

<details>
<summary>translate_app.rb</summary>

![translate_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/translate/translate_app.rb ':include :type=code')

</details>

### Voice Interpreter

![Voice Interpreter app icon](../assets/icons/voice-chat.png ':size=40')

This app translates the user's input text into another language and speaks it using speech synthesis. First, the assistant asks for the target language. Then, it translates the input text into the specified language.

<details>
<summary>voice_interpreter_app.rb</summary>

![voice_interpreter_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/voice_interpreter/voice_interpreter_app.rb ':include :type=code')

</details>

## Content Generation

### Novel Writer

![Novel Writer app icon](../assets/icons/novel.png ':size=40')

This application is for co-writing novels with the assistant. Create a novel with compelling characters, vivid descriptions, and a convincing plot. The story unfolds based on the user's prompts, maintaining consistency and flow.

<details>
<summary>novel_writer_app.rb</summary>

![novel_writer_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/novel_writer/novel_writer_app.rb ':include :type=code')

</details>

### Image Generator

![Image Generator app icon](../assets/icons/image-generator.png ':size=40')

This application generates images based on descriptions. If the prompt is not specific or is written in a language other than English, it returns an improved prompt and asks whether to proceed with the improved prompt. It uses the Dall-E 3 API internally.

Images are saved in the `Shared Folder` and also displayed in the chat.

<details>
<summary>image_generator_app.rb</summary>

![image_generator_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/image_generator/image_generator_app.rb ':include :type=code')

</details>

### Mail Composer

![Mail Composer app icon](../assets/icons/mail-composer.png ':size=40')

This application is for drafting emails in collaboration with the assistant. The assistant drafts emails based on the user's requests and specifications.

<details>
<summary>mail_composer_app.rb</summary>

![mail_composer_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/mail_composer/mail_composer_app.rb ':include :type=code')

</details>

### Mermaid Grapher

![Mermaid Grapher app icon](../assets/icons/diagram-draft.png ':size=40')

This application visualizes data using [mermaid.js](https://mermaid.js.org/). When you input any data or instructions, the agent generates Mermaid code for a flowchart and renders the image.

<details>
<summary>flowchart_grapher_app.rb</summary>

![flowchart_grapher_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/mermaid_grapher/mermaid_grapher_app.rb ':include :type=code')

</details>

### Music Composer

![Music Composer app icon](../assets/icons/music.png ':size=40')

This application creates simple sheet music using [ABC notation](https://en.wikipedia.org/wiki/ABC_notation) and plays it in Midi. Specify the instrument and the genre or style of music to be used.

<details>
<summary>music_composer_app.rb</summary>

![music_composer_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/music_composer/music_composer_app.rb ':include :type=code')

</details>

### Speech Draft Helper

![Speech Draft Helper app icon](../assets/icons/speech-draft-helper.png ':size=40')

In this app, users can submit speech drafts in the form of text strings, Word files, or PDF files. The app analyzes them and returns a revised version. It also provides suggestions and tips to make the speech more engaging and effective if needed. Additionally, it can provide an mp3 file of the speech.

<details>
<summary>speech_draft_helper_app.rb</summary>

![speech_draft_helper_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/speech_draft_helper/speech_draft_helper_app.rb ':include :type=code')

</details>

## Content Understanding

### Video Describer

![Video Describer app icon](../assets/icons/video.png ':size=40')

This is an application that analyzes video content and describes its content. The AI analyzes the video content and provides a detailed description of what is happening. The app extracts frames from the video, converts them into base64 PNG images, and extracts audio data from the video, saving it as an MP3 file. Based on these, the AI provides an overall description of the visual and audio information contained in the video file.

To use this app, users need to store the video file in the `Shared Folder` and provide the file name. Additionally, the frames per second (fps) for frame extraction must be specified. If the total number of frames exceeds 50, only 50 frames will be proportionally extracted from the video.

<details>
<summary>video_describer_app.rb</summary>

![video_describer_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/video_describer/video_describer_app.rb ':include :type=code')

</details>

### PDF Navigator

![PDF Navigator app icon](../assets/icons/pdf-navigator.png ':size=40')

This application reads PDF files and allows the assistant to answer user questions based on the content. Click the `Upload PDF` button to specify the file. The content of the file is divided into segments of the length specified by max_tokens, and text embeddings are calculated for each segment. Upon receiving input from the user, the text segment closest to the input sentence's text embedding value is passed to GPT along with the user's input, and a response is generated based on that content.

<details>
<summary>pdf_navigator_app.rb</summary>

![pdf_navigator_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/pdf_navigator/pdf_navigator_app.rb ':include :type=code')

</details>

![PDF RAG illustration](../assets/images/rag.png ':size=600')

### Content Reader

![Content Reader app icon](../assets/icons/document-reader.png ':size=40')

This application features an AI chatbot that examines and explains the content of provided files or web URLs. The explanation is presented in a clear and beginner-friendly manner. Users can upload files or URLs containing various text data, including programming code. If a URL is mentioned in the prompt message, the app automatically retrieves the content and seamlessly integrates it into the conversation with GPT.

To specify a file you want the AI to read, save the file in the `Shared Folder` and specify the file name in the User message. If the AI cannot find the file location, please verify the file name and inform the message that it is accessible from the current code execution environment.

Files in the following formats can be read from the `Shared Folder`:

- PDF
- Microsoft Word (docx)
- Microsoft PowerPoint (pptx)
- Microsoft Excel (xlsx)
- CSV
- Text (txt)

You can also load image files such as PNG and JPEG to have their content recognized and described. Additionally, audio files like MP3 can be loaded to transcribe their content into text.

<details>
<summary>content_reader_app.rb</summary>

![content_reader_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/content_reader/content_reader_app.rb ':include :type=code')

</details>

## Code Generation

### Code Interpreter

![Code Interpreter app icon](../assets/icons/code-interpreter.png ':size=40')

This application allows the AI to create and execute program code. The execution of the program uses a Python environment within a Docker container. Text data and images obtained as execution results are saved in the `Shared Folder` and also displayed in the chat.

If you have a file (such as Python code or CSV data) that you want the AI to read, save the file in the `Shared Folder` and specify the file name in the User message. If the AI cannot find the file location, please verify the file name and inform the message that it is accessible from the current code execution environment.

<details>
<summary>code_interpreter_app.rb</summary>

![code_interpreter_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/code_interpreter/code_interpreter_app.rb ':include :type=code')

</details>

### Coding Assistant

![Coding Assistant app icon](../assets/icons/coding-assistant.png ':size=40')

This is an application for writing computer program code. You can interact with an AI set up as a professional software engineer. It answers various questions, writes code, makes appropriate suggestions, and provides helpful advice through user prompts.

<details>
<summary>coding_assistant_app.rb</summary>

![coding_assistant_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/coding_assistant/coding_assistant_app.rb ':include :type=code')

</details>

### Jupyter Notebook

![Jupyter Notebook app icon](../assets/icons/jupyter-notebook.png ':size=40')

This application allows the AI to create Jupyter Notebooks and add cells and execute code within the cells based on user requests. The execution of the code uses a Python environment within a Docker container. The created Notebook is saved in the `Shared Folder`. The execution results are overwritten in the Jupyter Notebook.

<details>
<summary>jupyter_notebook_app.rb</summary>

![jupyter_notebook_app.rb](https://raw.githubusercontent.com/yohasebe/monadic-chat/main/docker/services/ruby/apps/jupyter_notebook/jupyter_notebook_app.rb ':include :type=code')

</details>