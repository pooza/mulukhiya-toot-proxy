module MulukhiyaTootProxy
  class Account
    attr_reader :token

    def initialize(key)
      if @token = key[:token]
        @params = Mastodon.lookup_token_owner(@token)
      elsif key[:id]
        @params = Mastodon.lookup_account(key[:id])
      end
    end

    def id
      return self['id']
    end

    def [](key)
      return @params[key]
    end

    def config
      @config ||= UserConfigStorage.new[id]
      return @config
    end

    def webhook
      @webhook ||= Webhook.new(config)
      return @webhook
    end

    def admin?
      return @params['admin'] == 't'
    end

    def moderator?
      return @params['moderator'] == 't'
    end

    def locked?
      return @params['locked'] == 't'
    end

    def enable?(handler_name)
      return false if config["/handler/#{handler_name}/disable"]
      return false if config['/handler/default/disable']
      return true
    end
  end
end
