module Mulukhiya
  class GrowiAnnounceHandler < AnnounceHandler
    def disable?
      return true unless controller_class.growi?
      return true unless sns.account&.growi
      return super
    end

    def announce(params = {})
      params[:format] = :md
      response = sns.account.growi.clip(body: create_body(params))
      result.push(path: response.dig('page', 'path'))
    end
  end
end
