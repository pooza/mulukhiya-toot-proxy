module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      token ||= @config['/agent/test/token']
      super
    end

    def search(keyword, params = {})
      params[:limit] ||= @config['/mastodon/search/limit']
      return super
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def account
      @account ||= Environment.account_class.get(token: @token)
      return @account
    rescue
      return nil
    end

    def notify(account, message)
      return toot(
        MastodonController.status_field => [account.acct.to_s, message].join("\n"),
        'visibility' => MastodonController.visibility_name('direct'),
      )
    end
  end
end
