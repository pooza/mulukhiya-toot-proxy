module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package
    include ServiceMethods

    alias info nodeinfo

    def upload(path, params = {})
      params[:trim_times].times {ImageFile.new(path).trim!} if params&.dig(:trim_times)
      return super
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

    def notify(account, message, response = nil)
      message = [account.acct.to_s, message.clone].join("\n")
      message.ellipsize!(TootParser.new.max_length)
      status = {
        MastodonController.status_field => message,
        'visibility' => MastodonController.visibility_name('direct'),
      }
      status['in_reply_to_id'] = response['id'] if response
      return post(status)
    end

    def default_token
      return config['/agent/test/token']
    end
  end
end
