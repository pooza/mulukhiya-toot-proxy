module Mulukhiya
  class EmojiSpacingHandler < Handler
    SHORTCODE_PATTERN = /:([A-Za-z0-9_]+):/
    ZWSP = "​".freeze
    SEPARATOR_PATTERN = /[\s​]/

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return if @status.blank?
      return unless @status.include?(':')
      rewritten = inject_separators(@status)
      return if rewritten == @status
      parser.text = payload[text_field] = rewritten
      result.push(rewritten:)
      return rewritten
    end

    private

    def inject_separators(text)
      return text.gsub(SHORTCODE_PATTERN) do
        match = Regexp.last_match
        before_char = match.begin(0).positive? ? text[match.begin(0) - 1] : nil
        after_char = text[match.end(0)]
        prefix = needs_separator?(before_char) ? ZWSP : ''
        suffix = needs_separator?(after_char) ? ZWSP : ''
        "#{prefix}#{match[0]}#{suffix}"
      end
    end

    def needs_separator?(char)
      return false if char.nil?
      return !SEPARATOR_PATTERN.match?(char)
    end
  end
end
