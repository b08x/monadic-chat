# frozen_string_literal: true

module StringUtils
  module_function

  # language detection using CLD gem
  def detect_language(text)
    CLD.detect_language(text)[:code]
  end

  def markdown_to_html(text, mathjax: false)
    # if text is not a String, return a string representation of it
    return text.to_s unless text.is_a?(String)

    text = text.gsub(/\[^([0-9])^\]/) { "[^#{Regexp.last_match(1)}]" }
    text = text.gsub(/(!\[[^\]]*\]\()(['"])([^\s)]+)(['"])(\))/, '\1\3\5')

    if mathjax
      # Arrays to store the mathjax codes
      block_mathjax = []
      inline_mathjax = []

      # Replace $$...$$ with placeholders
      text = text.gsub(/\$\$(.*?)\$\$/m) do
        block_mathjax << Regexp.last_match(1)
        "BLOCK_MATHJAX_PLACEHOLDER_#{block_mathjax.size - 1}"
      end

      # Replace $...$ with placeholders
      text = text.gsub(/\$(.*?)\$/m) do
        inline_mathjax << Regexp.last_match(1)
        "INLINE_MATHJAX_PLACEHOLDER_#{inline_mathjax.size - 1}"
      end

      # Convert markdown to HTML using Kramdown
      html = Kramdown::Document.new(text,
                                    syntax_highlighter: :rouge,
                                    input: "GFM",
                                    syntax_highlighter_ops: {
                                      guess_lang: true
                                    }).to_html.gsub(/(?:\\)+n/) { "\n" }

      # add an extra backslash to the backslash in the mathjax code in inline_mathjax
      inline_mathjax.map! do |code|
        code.gsub(/(?:\r)+/, "\\r")
            .gsub(/(?:\t)+/, "\\t")
      end

      # Replace placeholders with the original mathjax codes
      block_mathjax.each_with_index do |code, index|
        html.gsub!("BLOCK_MATHJAX_PLACEHOLDER_#{index}", "$$#{code}$$")
      end

      inline_mathjax.each_with_index do |code, index|
        html.gsub!("INLINE_MATHJAX_PLACEHOLDER_#{index}", "$#{code}$")
      end

      html
    else
      Kramdown::Document.new(text,
                             syntax_highlighter: :rouge,
                             input: "GFM",
                             syntax_highlighter_ops: {
                               guess_lang: true
                             }).to_html
    end
  end
end