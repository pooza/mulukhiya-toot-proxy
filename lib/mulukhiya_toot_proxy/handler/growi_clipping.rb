module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def hook_pre_toot(body, params = {})
      return unless body['status'] =~ /#growi/i
      path = GrowiClipper.create_path(mastodon.account['username'])
      res = GrowiClipper.create({account_id: mastodon.account_id}).clip({
        body: body['status'],
        path: path,
      })
      body['status'] += "\n#{create_uri(res.data.path)}"
      @result.push(path)
    end

    private

    def create_uri(path)
      uri = MastodonURI.parse(user_config['/growi/url'])
      uri.path = path
      return nil unless uri.absolute?
      return uri
    rescue => e
      @logger.error(e)
      return nil
    end
  end
end
