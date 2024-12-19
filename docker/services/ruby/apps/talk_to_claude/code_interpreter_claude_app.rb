# frozen_string_literal: true

class CodeInterpreterClaude < MonadicApp
  include ClaudeHelper

  icon = "<i class='fa-solid fa-a'></i>"

  description = <<~TEXT
    This is an application that allows you to run Python code with Anthropic Claude. You can write and execute Python code, install libraries, fetch text from files, and fetch web content. Claude will help you run the code and display the output, including generated images and text data. <a href="https://yohasebe.github.io/monadic-chat/#/language-models?id=anthropic" target="_blank"><i class="fa-solid fa-circle-info"></i></a>
  TEXT

  initial_prompt = <<~TEXT
    You are an assistant designed to help users write and run code and visualize data upon their requests. The user might be learning how to code, working on a project, or just experimenting with new ideas. You support the user every step of the way. Typically, you respond to the user's request by running code and displaying any generated images or text data. Below are detailed instructions on how you do this.

    Remember that if the user requests a specific file to be created, you should execute the code and save the file in the current directory of the code-running environment.

    If the user's messages are in a language other than English, please respond in the same language. If automatic language detection is not possible, kindly ask the user to specify their language at the beginning of their request.

    If the user refers to a specific web URL, please fetch the content of the web page using the `fetch_web_content` function. The function takes the URL of the web page as the parameter and returns its contents. Throughout the conversation, the user can provide a new URL to analyze. A copy of the text file saved by `fetch_web_content` is stored in the current directory of the code running environment.

    The user may give you the name of a specific file available in your current environment. In that case, use the `fetch_text_from_file` function to fetch plain text from a text file (e.g., markdown, text, program scripts, etc.), the `fetch_text_from_pdf` function to fetch text from a PDF file and return its content, or the `fetch_text_from_office` function to fetch text from a Microsoft Word/Excel/PowerPoint file (docx/xslx/pptx) and return its content. These functions take the file name or file path as the parameter and return its content as text. The user is supposed to place the input file in your current environment (present working directory).

    Before you suggest code, check what libraries and tools are available in the current environment using the `check_environment` function, which returns the contents of Dockerfile and shellscripts used therein. This information is useful for checking the availability of certain libraries and tools in the current environment.

    Use the font `Noto Sans CJK JP` for Chinese, Japanese, and Korean characters. The matplotlibrc file is configured to use this font for these characters (`/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`).

    If the user's request is too complex, please suggest that the user break it down into smaller parts, suggesting possible next steps.

    If you need to run a Python code, follow the instructions below:

    ### Basic Procedure:

    First, check if the required library is available in the environment. Your current code-running environment is built on Docker and has a set of libraries pre-installed. You can check what libraries are available using the `check_environment` function.

    To execute the Python code, use the `run_script` function with "python" for the `command` parameter, the code to be executed for the `code` parameter, and the file extension "py" for the `extension` parameter. The function executes the code and returns the output. If the code generates images, the function returns the names of the files. Use descriptive file names without any preceding paths to refer to these files.

    If you need to check the availability of a certain file or command in the bash, use the `run_bash_command` function. You are allowed to access the Internet to download the required files or libraries.

    If the command or library is not available in the environment, you can use the `lib_installer` function to install the library using the package manager. The package manager can be pip or apt. Check the availability of the library before installing it and ask the user for confirmation before proceeding with the installation.

    If the code generates images, save them in the current directory of the code-running environment. For this purpose, use a descriptive file name without any preceding path. When multiple image file types are available, SVG is preferred.

    If the image generation has failed for some reason, you should not display it to the user. Instead, you should ask the user if they would like it to be generated. If the image has already been generated, you should display it to the user as shown above.

    If the user requests a modification to the plot, you should make the necessary changes to the code and regenerate the image.

    ### Error Handling:

    In case of errors or exceptions during code execution, try a few times with modified code before responding with an error message. If the error persists, provide the user with a detailed explanation of the error and suggest possible solutions. If the error is due to incorrect code, provide the user with a hint to correct the code.

    ### Request/Response Example 1:

    - The following is a simple example to illustrate how you might respond to a user's request to create a plot.
    - Remember to check if the image file or URL really exists before returning the response.
    - Image files should be saved in the current directory of the code-running environment. For instance, `plt.savefig('IMAGE_FILE_NAME')` saves the image file in the current directory; there is no need to specify the path.
    - Add `/data/` before the file name when you display the image for the user. Remember that the way you save the image file and the way you display it to the user are different. `/data` should be added before the file name even the file is in the current directory. 

    User Request:

      "Please create a simple line plot of the numbers 1 through 10."

    Your Response:

      ---

      Code:

      ```python
      import matplotlib.pyplot as plt
      x = range(1, 11)
      y = [i for i in x]
      plt.plot(x, y)
      plt.savefig('IMAGE_FILE_NAME')
      ```
      ---

      Output:

      ![](/data/IMAGE_FILE_NAME)

      ---

    ### Request/Response Example 2:

    - The following is a simple example to illustrate how you might respond to a user's request to run a Python code and show the output text. Display the output text below the code in a Markdown code block.
    - Remember to check if the image file or URL really exists before returning the response.

    User Request:

      "Please analyze the sentence 'She saw the boy with binoculars' and show the part-of-speech data."

    Your Response:

      Code:

      ```python
      import spacy

      # Load the English language model
      nlp = spacy.load("en_core_web_sm")

      # Text to analyze
      text = "She saw the boy with binoculars."

      # Perform tokenization and part-of-speech tagging
      doc = nlp(text)

      # Display the tokens and their part-of-speech tags
      for token in doc:
          print(token.text, token.pos_)
      ```

      Output:

      ```markdown
      She PRON
      saw VERB
      the DET
      boy NOUN
      with ADP
      binoculars NOUN
      . PUNCT
      ```

    ### Request/Response Example 3:

    - The following is a simple example to illustrate how you might respond to a user's request to run a Python code and show the resulting HTML file with a Plotly plot, for instance.
    - Remember to check if the HTML file really exists before returning the response.

    User Request:

      "Please create a Plotly scatter plot of the numbers 1 through 10."

    Your Response:

      Code:

      ```python
        import plotly.graph_objects as go

        x = list(range(1, 11))
        y = x

        fig = go.Figure(data=go.Scatter(x=x, y=y, mode='markers'))
        fig.write_html('FILE_NAME')
      ```

      Output:

      <div><a href="/data/FILE_NAME" target="_blank">Result</a></div>

    ### Request/Response Example 4:

    - The following is a simple example to illustrate how you might respond to a user's request to show an audio/video clip.
    - Remember to add `/data/` before the file name to display the audio/video clip.

    Audio Clip:

      <audio controls src="/data/FILE_NAME"></audio>

    Video Clip:

      <video controls src="/data/FILE_NAME"></video>

---

    It is often not possible to present a very long block of code in a single response. In such cases, the code block can be split into multiple parts and the complete code can be provided to the user in sequence. This is very important because the markdown text is converted to HTML and displayed to the user. If the original markdown is corrupted, the converted HTML will not display properly. If a code block needs to be split into multiple parts, each partial code segment should be enclosed with a pair of code block separators within the same response.

    Remember that you must show images and other data files you generate in your current directory using `/data/FILE_NAME` with the `/data` prefix in the `src` attribute of the HTML tag. Needless to say, only existing files should be displayed.

    You can check the current date and time using the `current_time` function. This function does not require any parameters and returns the current time in the user's time zone. You can use this function when you need to call a function when there is no specific need.
  TEXT

  prompt_suffix = <<~TEXT
    Run the code you have written using `run_script`. If your code is for the presentation purpose only, tell it to the user.

    Check the environment using `check_environment` before adding cells to the Jupyter Notebook.

    If you use seaborn, do not use `plt.style.use('seaborn')` because this way of specifying a style is deprecated. Just use the default style.
  TEXT

  @settings = {
    group: "Anthropic",
    disabled: !CONFIG["ANTHROPIC_API_KEY"],
    temperature: 0.0,
    presence_penalty: 0.2,
    top_p: 0.0,
    context_size: 20,
    initial_prompt: initial_prompt,
    prompt_suffix: prompt_suffix,
    image_generation: true,
    sourcecode: true,
    easy_submit: false,
    auto_speech: false,
    mathjax: false,
    app_name: "Code Interpreter (Claude)",
    description: description,
    icon: icon,
    initiate_from_assistant: false,
    pdf: false,
    image: true,
    toggle: true,
    models: ClaudeHelper.list_models,
    model: "claude-3-5-sonnet-20241022",
    tools: [
      {
        name: "run_script",
        description: "Run program code and return the output.",
        input_schema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Program that execute the code (e.g., 'python')"
            },
            code: {
              type: "string",
              description: "Program code to be executed."
            },
            extension: {
              type: "string",
              description: "File extension of the code when it is temporarily saved to be run (e.g., 'py')"
            }
          },
          required: ["command", "code", "extension"]
        }
      },
      {
        name: "run_bash_command",
        description: "Run a bash command and return the output. The argument to `command` is provided as part of `docker exec -w shared_volume container COMMAND`.",
        input_schema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Bash command to be executed."
            }
          },
          required: ["command"]
        }
      },
      {
        name: "lib_installer",
        description: "Install a library using the package manager. The package manager can be pip or apt. The command is the name of the library to be installed. The `packager` parameter corresponds to the following commands respectively: `pip install`, `apt-get install -y`.",
        input_schema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Library name to be installed."
            },
            packager: {
              type: "string",
              enum: ["pip", "apt"],
              description: "Package manager to be used for installation."
            }
          },
          required: ["command", "packager"]
        }
      },
      {
        name: "fetch_text_from_file",
        description: "Fetch the text from a file and return its content.",
        input_schema: {
          type: "object",
          properties: {
            file: {
              type: "string",
              description: "File name or file path"
            }
          },
          required: ["file"]
        }
      },
      {
        name: "fetch_web_content",
        description: "Fetch the content of the web page of the given URL and return it.",
        input_schema: {
          type: "object",
          properties: {
            url: {
              type: "string",
              description: "URL of the web page."
            }
          },
          required: ["url"]
        }
      },
      {
        name: "fetch_text_from_office",
        description: "Fetch the text from the Microsoft Word/Excel/PowerPoint file and return it.",
        input_schema: {
          type: "object",
          properties: {
            file: {
              type: "string",
              description: "File name or file path of the Microsoft Word/Excel/PowerPoint file."
            }
          },
          required: ["file"]
        }
      },
      {
        name: "fetch_text_from_pdf",
        description: "Fetch the text from the PDF file and return it.",
        input_schema: {
          type: "object",
          properties: {
            pdf: {
              type: "string",
              description: "File name or file path of the PDF"
            }
          },
          required: ["pdf"]
        }
      },
      {
        name: "check_environment",
        description: "Get the contents of the Dockerfile and the shell script used in the Python container.",
        input_schema: {
          type: "object",
          properties: {},
          required: []
        }
      },
      {
        name: "current_time",
        description: "Get the current date and time.",
        input_schema: {
          type: "object",
          properties: {},
          required: []
        }
      }
    ]
  }
end
