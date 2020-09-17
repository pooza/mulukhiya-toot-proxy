module Mulukhiya
  class AnnouncementHandler < Handler
    def handle_announce(announcement, params = {})
      return announcement unless params[:sns]
      @status = announcement[:content] || announcement[:text]
      announce(announcement, params)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, accouncement: accouncement)
      return false
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
