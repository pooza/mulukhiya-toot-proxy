module Mulukhiya
  class SpoilerHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return if parser.command?
      subject = payload[spoiler_field]
      tags.merge(parser_class.new(subject).tags)
      return unless subject&.match?(pattern)
      subject = subject.sub(Regexp.new("^#{shortcode} *"), '')
      payload[spoiler_field] = "#{shortcode} #{subject}"
      result.push(subject:)
    end

    def shortcode
      return status_class.spoiler_shortcode
    end

    def pattern
      return status_class.spoiler_pattern
    end
  end
end
