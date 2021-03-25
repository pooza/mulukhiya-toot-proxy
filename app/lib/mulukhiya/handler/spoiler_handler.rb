module Mulukhiya
  class SpoilerHandler < Handler
    def handle_pre_toot(body, params = {})
      subject = body[controller_class.spoiler_field]
      return body unless subject&.match?(pattern)
      body[controller_class.spoiler_field] = "#{shortcode} #{subject}"
      result.push(subject: subject)
      return body
    end

    def shortcode
      return ":#{config['/handler/spoiler/emoji']}:"
    end

    def pattern
      return Regexp.new(config['/handler/spoiler/pattern'])
    end
  end
end
