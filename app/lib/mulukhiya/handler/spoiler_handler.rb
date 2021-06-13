module Mulukhiya
  class SpoilerHandler < Handler
    def handle_pre_toot(body, params = {})
      self.status = body[status_field]
      return body if parser.command?
      subject = body[controller_class.spoiler_field]
      return body unless subject&.match?(pattern)
      subject.sub!(Regexp.new("^#{shortcode} *"), '')
      body[controller_class.spoiler_field] = "#{shortcode} #{subject}"
      result.push(subject: subject)
      return body
    end

    def shortcode
      return ":#{config['/spoiler/emoji']}:"
    end

    def pattern
      return Regexp.new(config['/spoiler/pattern'])
    end
  end
end
