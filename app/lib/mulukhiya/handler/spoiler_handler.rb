module Mulukhiya
  class SpoilerHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return payload if parser.command?
      subject = payload[spoiler_field]
      return payload unless subject&.match?(pattern)
      subject.sub!(Regexp.new("^#{shortcode} *"), '')
      payload[spoiler_field] = "#{shortcode} #{subject}"
      result.push(subject: subject)
      return payload
    end

    def shortcode
      return ":#{config['/spoiler/emoji']}:"
    end

    def pattern
      return Regexp.new(config['/spoiler/pattern'])
    end
  end
end
