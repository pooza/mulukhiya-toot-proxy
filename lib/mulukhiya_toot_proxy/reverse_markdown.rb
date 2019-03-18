require 'reverse_markdown'

module MulukhiyaTootProxy
  class ReverseMarkdown
    def self.convert(source)
      return source unless source.present?
      text = source.clone
      text.gsub!(/```.*?```/m) do |block|
        "<code>#{block.gsub(%r{<br */?>}, '__NEWLINE__')}</code>"
      end
      text = ::ReverseMarkdown.convert(text)
      text.gsub!('__NEWLINE__', "\n")
      text.gsub!(/\s?````/, '```')
      text.gsub!(/\[.+?\]/) do |block|
        block.gsub(/#/, '\\#')
      end
      return text
    end
  end
end
