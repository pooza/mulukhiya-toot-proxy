module Mulukhiya
  class AnnounceHandler < Handler
    attr_reader :sns

    def disable?
      return true unless controller_class.announcement?
      return true unless Worker.create(:announcement).disable?
      return true unless info_agent_service
      return super
    end

    def handle_announce(payload, params = {})
      self.payload = payload
      announce(params) if @sns = params[:sns]
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, payload:)
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
