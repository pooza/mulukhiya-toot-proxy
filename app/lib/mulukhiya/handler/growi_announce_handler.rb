module Mulukhiya
  class GrowiAnnounceHandler < AnnounceHandler
    def announce(announcement, params = {})
      return announcement unless growi
      params = params.clone
      params[:format] = :md
      response = growi.clip(body: create_body(announcement, params))
      result.push(path: response['page']['path'])
      return announcement
    end

    def growi
      return sns.account.growi rescue nil
    end
  end
end
