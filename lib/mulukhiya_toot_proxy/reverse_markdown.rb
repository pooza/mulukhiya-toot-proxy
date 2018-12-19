require 'reverse_markdown'

module MulukhiyaTootProxy
  class ReverseMarkdown
    def self.convert(text)
      text.gsub!(/```.*?```/m) do |block|
        "<code>#{block.gsub(%r{<br */?>}, '__NEWLINE__')}</code>"
      end
      text = ::ReverseMarkdown.convert(text)
      text.gsub!('__NEWLINE__', "\n")
      text.gsub!(/\s?````/, '```')
      return text
    end
  end
end
