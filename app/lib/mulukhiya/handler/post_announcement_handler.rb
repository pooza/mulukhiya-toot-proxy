module Mulukhiya
  class PostAnnouncementHandler < Handler
    def handle_announce(announcement, params = {})
      return unless params[:sns]
      @status = announcement[:content] || announcement[:text]
      body = {
        status_field => create_body(announcement),
        'visibility' => Environment.controller_class.visibility_name('unlisted'),
      }
      params[:sns].post(body)
      result.push(body)
    end

    def create_body(announcement, params = {})
      params[:body] = parser.to_sanitized
      params.merge!(announcement)
      template = Template.new('announcement')
      template.params = params
      return template.to_s
    end
  end
end
