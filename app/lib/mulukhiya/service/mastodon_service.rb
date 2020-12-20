module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package

    def upload(path, params = {})
      params[:trim_times].times {ImageFile.new(path).trim!} if params&.dig(:trim_times)
      return super
    end

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def access_token
      return Environment.access_token_class.first(token: token) if token
      return nil
    end

    def search(keyword, params = {})
      params[:limit] ||= config['/mastodon/search/limit']
      return super
    end

    def oauth_client
      unless client = redis.get('oauth_client')
        client = http.post('/api/v1/apps', {
          body: {
            client_name: package_class.name,
            website: config['/package/url'],
            redirect_uris: config['/mastodon/oauth/redirect_uri'],
            scopes: config['/mastodon/oauth/scopes'].join(' '),
          }.to_json,
        }).body
        redis.set('oauth_client', client)
      end
      return JSON.parse(client)
    end

    def clear_oauth_client
      redis.unlink('oauth_client')
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def notify(account, message, response = nil)
      toot = {
        MastodonController.status_field => [account.acct.to_s, message].join("\n"),
        'visibility' => MastodonController.visibility_name('direct'),
      }
      toot['in_reply_to_id'] = response['id'] if response
      return post(toot)
    end

    def default_token
      return config['/agent/test/token']
    end
  end
end
