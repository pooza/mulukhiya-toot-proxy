module Mulukhiya
  class ImageCopyrightHandler < Handler
    def disable?
      return true unless tag.present?
      return true unless message.present?
      return true unless uri.present?
      return true unless uri.absolute?
      return super
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless appendable?
      lines = [message, uri.to_s, nil].concat(status_lines)
      parser.text = payload[text_field] = lines.join("\n")
      result.push(tag: tag)
    end

    def appendable?
      return false unless payload[attachment_field].present?
      return tags.member?(tag) || parser.tags.member?(tag)
    end

    def tag
      return handler_config(:tag)
    end

    def message
      return handler_config(:message)
    end

    def uri
      return Ginseng::URI.parse(handler_config(:url))
    end
  end
end
