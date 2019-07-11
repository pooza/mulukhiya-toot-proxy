module MulukhiyaTootProxy
  class FavDropboxClippingHandler < Handler
    def disable?
      return true if mastodon.account.config["/handler/#{underscore_name}/disable"].nil?
      return super
    end

    def handle_post_fav(body, params = {})
      @logger.info(body)
      @result.push(body['id'].to_i)
    end
  end
end
