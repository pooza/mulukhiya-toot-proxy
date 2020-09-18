module Mulukhiya
  class DropboxAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      return announcement unless dropbox
      params = params.clone
      params[:format] = :md
      r = dropbox.clip(body: create_body(announcement, params))
      result.push(path: r.path_display)
      return announcement
    end

    private

    def dropbox
      return sns.account.dropbox
    rescue
      return nil
    end
  end
end
