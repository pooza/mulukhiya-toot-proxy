module Mulukhiya
  class GrowiAnnouncementHandler < AnnouncementHandler
    def announce(announcement, params = {})
      return announcement unless growi
      params = params.clone
      params[:format] = :md
      r = growi.clip(body: create_body(announcement, params))
      result.push(path: r['page']['path'])
      return announcement
    rescue => e
      errors.push(message: e.message)
      return announcement
    end

    private

    def growi
      return sns.account.growi
    rescue
      return nil
    end
  end
end
