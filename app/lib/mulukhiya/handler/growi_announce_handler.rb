module Mulukhiya
  class GrowiAnnounceHandler < AnnounceHandler
    def disable?
      return true unless sns.account.growi
      return super
    end

    def announce(params = {})
      params[:format] = :md
      response = sns.account.growi.clip(body: create_body(params))
      result.push(path: response['data']['page']['path'])
    end
  end
end
