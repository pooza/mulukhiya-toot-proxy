module Mulukhiya
  class MfmizeHandler < Handler
    def disable?
      return true unless Environment.note?
      return super
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      parser.text = payload[text_field] = parser.to_mfm
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end
  end
end
