module Mulukhiya
  class GrowiAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      return body unless growi = params[:sns].account.growi
      params = params.clone
      params[:format] = :md
      body = {
        path: GrowiClipper.create_path(params[:sns].account.username),
        body: create_body(announcement, params),
      }
      growi.clip(body)
      result.push(body)
    end
  end
end
