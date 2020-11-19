module Mulukhiya
  class AnnouncementHandler < Handler
    attr_reader :sns

    def handle_announce(announcement, params = {})
      return announcement unless @sns = params[:sns]
      return announcement unless @status = announcement[:content] || announcement[:text]
      return announce(announcement, params)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, announcement: announcement)
      return false
    end

    def announce(announcement, params = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(announcement, params = {})
      params[:format] ||= :sanitized
      params.merge!(announcement)
      template = Template.new('announcement')
      params[:body] = parser.send("to_#{params[:format]}".to_sym)
      template.params = params
      return template.to_s
    end
  end
end
