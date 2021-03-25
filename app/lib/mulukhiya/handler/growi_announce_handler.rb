module Mulukhiya
  class GrowiAnnounceHandler < AnnounceHandler
    def disable?
      return true unless sns.account.growi
      return super
    end

    def announce(announcement, params = {})
      params = params.clone
      params[:format] = :md
      response = sns.account.growi.clip(body: create_body(announcement, params))
      result.push(path: response['page']['path'])
      return announcement
    end
  end
end
