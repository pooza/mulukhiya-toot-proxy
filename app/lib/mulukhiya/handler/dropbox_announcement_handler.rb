module Mulukhiya
  class DropboxAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      return announcement unless dropbox
      params = params.clone
      params[:format] = :md
      response = dropbox.clip(body: create_body(announcement, params))
      result.push(path: response.path_display)
      return announcement
    end

    def dropbox
      return sns.account.dropbox rescue nil
    end
  end
end
