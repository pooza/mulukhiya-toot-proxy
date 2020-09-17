module Mulukhiya
  class PostAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      body = {
        status_field => create_body(announcement, params),
        'visibility' => Environment.controller_class.visibility_name('unlisted'),
      }
      params[:sns].post(body)
      result.push(body)
    end
  end
end
