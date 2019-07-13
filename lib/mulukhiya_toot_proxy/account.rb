module MulukhiyaTootProxy
  class Account
    attr_reader :params

    def initialize(key)
      @logger = Logger.new
      if @token = key[:token]
        @params = Mastodon.lookup_token_owner(@token)
      elsif key[:id]
        @params = Mastodon.lookup_account(key[:id])
      end
      @params ||= {}
    end

    def id
      return self[:id]&.to_i
    end

    def username
      return self[:username]
    end

    def display_name
      return self[:display_name]
    end

    alias to_h params

    def [](key)
      return @params[key]
    end

    def config
      @config ||= UserConfigStorage.new[id]
      return @config
    rescue => e
      @logger.error(e)
      return {}
    end

    def webhook
      @webhook ||= Webhook.new(config)
      return @webhook
    rescue => e
      @logger.error(e)
      return nil
    end

    def slack
      unless @slack
        uri = Ginseng::URI.parse(config['/slack/webhook'])
        raise 'invalid URI' unless uri&.absolute?
        @slack = Slack.new(uri)
      end
      return @slack
    rescue
      return nil
    end

    def create_clipper(name)
      return "MulukhiyaTootProxy::#{name.to_s.camelize}Clipper".constantize.create(account_id: id)
    end

    def admin?
      return @params[:admin] == 't'
    end

    def moderator?
      return @params[:moderator] == 't'
    end

    def service?
      return @params[:actor_type] == 'Service'
    end

    alias bot? service?

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
