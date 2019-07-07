module MulukhiyaTootProxy
  class Account
    def initialize(key)
      if @token = key[:token]
        @params = Mastodon.lookup_token_owner(@token).with_indifferent_access
      elsif key[:id]
        @params = Mastodon.lookup_account(key[:id]).with_indifferent_access
      end
    end

    def id
      return self[:id]
    end

    def username
      return self[:username]
    end

    def display_name
      return self[:display_name]
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
      return @params[:admin] == 't'
    end

    def moderator?
      return @params[:moderator] == 't'
    end

    def locked?
      return @params[:locked] == 't'
    end

    def disable?(handler_name)
      return true if config["/handler/#{handler_name}/disable"]
      return true if config['/handler/default/disable']
      return false
    end
  end
end
