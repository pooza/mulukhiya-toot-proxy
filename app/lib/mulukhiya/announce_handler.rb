module Mulukhiya
  class AnnounceHandler < Handler
    attr_reader :sns

    def handle_announce(payload, params = {})
      self.payload = payload
      return payload unless @sns = params[:sns]
      return announce(payload, params)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, payload: payload)
      return false
    end

    def announce(payload, params = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def payload=(payload)
      @payload = payload
      @status = payload[:content] || payload[:text] || ''
    end

    def create_body(payload, params = {})
      self.payload = payload
      params[:format] ||= :sanitized
      params.merge!(payload)
      params[:body] = parser.send("to_#{params[:format]}".to_sym)
      template = Template.new('announcement')
      template.params = params
      return template.to_s
    end
  end
end
