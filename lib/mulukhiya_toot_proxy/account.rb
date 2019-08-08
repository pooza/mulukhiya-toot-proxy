module MulukhiyaTootProxy
  class Account
    attr_reader :params
    attr_reader :token

    def initialize(key)
      @logger = Logger.new
      if @token = key[:token]
        @params = Mastodon.lookup_token_owner(@token)
      elsif key[:id]
        @params = Mastodon.lookup_account(key[:id].to_i)
      end
      raise Ginseng::NotFoundError, "Toot '#{key.to_json}' not found" unless @params.present?
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
      raise "Invalid webhook #{config.to_json}" unless @webhook.exist?
      return @webhook
    rescue => e
      @logger.error(e)
      return nil
    end

    def slack
      unless @slack
        uri = Ginseng::URI.parse(config['/slack/webhook'])
        raise "Invalid URI #{config['/slack/webhook']}" unless uri&.absolute?
        @slack = Slack.new(uri)
      end
      return @slack
    rescue => e
      @logger.error(e)
      return nil
    end

    def growi
      @growi ||= GrowiClipper.create(account_id: id)
      return @growi
    rescue => e
      @logger.error(e)
      return nil
    end

    def dropbox
      @dropbox ||= DropboxClipper.create(account_id: id)
      return @dropbox
    rescue => e
      @logger.error(e)
      return nil
    end

    def recent_toot
      rows = Postgres.instance.execute('recent_toot', {id: id})
      return Toot.new(id: rows.first['id'].to_i) if rows.present?
      return nil
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
