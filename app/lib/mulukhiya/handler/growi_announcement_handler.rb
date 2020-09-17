module Mulukhiya
  class GrowiAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      return announcement unless growi
      params = params.clone
      params[:format] = :md
      growi.clip(path: path, body: create_body(announcement, params))
      result.push(path: path)
      return announcement
    end

    private

    def path
      return GrowiClipper.create_path(sns.account.username)
    end

    def growi
      return sns.account.growi
    rescue
      return nil
    end
  end
end
