module Mulukhiya
  class ImageCopyrightHandler < Handler
    def toggleable?
      return false unless tag.present?
      return false unless message.present?
      return false unless uri.present?
      return false unless uri.absolute?
      return super
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless appendable?
      lines = [message, uri.to_s, nil].concat(status_lines)
      parser.text = payload[text_field] = lines.join("\n")
      result.push(tag:)
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
