module Mulukhiya
  class AnnounceHandler < Handler
    attr_reader :sns

    def handle_announce(payload, params = {})
      self.payload = payload
      announce(params) if @sns = params[:sns]
      return payload
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, payload: payload)
      return false
    end

    def announce(params = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def payload=(payload)
      @payload = payload
      @status = payload[:content] || payload[:text] || ''
    end

    def create_body(params = {})
      params[:format] ||= :sanitized
      params.merge!(payload)
      params[:body] = parser.send("to_#{params[:format]}".to_sym)
      template = Template.new('announcement')
      template.params = params
      return template.to_s
    end
  end
end
