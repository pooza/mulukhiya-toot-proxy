module Mulukhiya
  class EmojiSpacingHandler < Handler
    # Mastodon の custom emoji shortcode は仕様上 [a-zA-Z0-9_]{2,} だが、
    # 純数字 (例 :34:) は時刻 12:34:56 やポート host:8080 等との誤認源になる。
    # 実用上の shortcode は英字または _ 始まりが圧倒的多数なため、こちらに限定する。
    SHORTCODE_PATTERN = /:([A-Za-z_][A-Za-z0-9_]+):/
    ZWSP = '​'.freeze
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
