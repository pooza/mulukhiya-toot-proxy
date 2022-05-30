module Mulukhiya
  class GrowiAnnounceHandler < AnnounceHandler
    def toggleable?
      return false unless controller_class.growi?
      return false unless sns.account&.growi
      return super
    end

    def announce(params = {})
      params[:format] = :md
      response = sns.account.growi.clip(body: create_body(params))
      result.push(path: response.dig('data', 'page', 'path'))
    end
  end
end
