module Mulukhiya
  module AccountMethods
    include SNSMethods

    def user_config
      @user_config ||= UserConfig.new(id)
      return @user_config
    end

    def acct
      @acct ||= Acct.new("@#{username}@#{host}")
      return @acct
    end

    def roles
      return []
    end

    def reactionable?
      http = HTTP.new
      http.base_uri = "https://#{acct.host}"
      headers = {'X-Mulukhiya' => Package.full_name}
      r = http.get('/.well-known/nodeinfo', {headers:}).parsed_response
      r = http.get(r['links'].first['href'], {headers:}).parsed_response
      software = r.dig('software', 'name')
      return true if config["/#{software.underscore}/features/reaction"] rescue nil
      capabilities = http.get('/api/v1/instance').parsed_response['fedibird_capabilities'] || []
      return true if capabilities.member?('emoji_reaction')
      return false
    rescue => e
      e.log(acct: acct.to_s)
      return false
    end

    def service
      unless @service
        @service = sns_class.new
        @service.token = token
        @service.retry_limit = 1
      end
      return @service
    end

    def webhook
      return Webhook.new(user_config)
    rescue => e
      e.log
      return nil
    end

    def lemmy
      return nil unless [:url, :user, :password].all? {|k| user_config["/lemmy/#{k}"]}
      @lemmy ||= LemmyClipper.new(
        url: user_config['/lemmy/url'],
        user: user_config['/lemmy/user'],
        password: user_config['/lemmy/password'],
        community: user_config['/lemmy/community'],
      )
      return @lemmy
    rescue => e
      e.log(acct: acct.to_s)
      return nil
    end

    def piefed
      return nil unless [:url, :user, :password].all? {|k| user_config["/piefed/#{k}"]}
      @piefed ||= PiefedClipper.new(
        url: user_config['/piefed/url'],
        user: user_config['/piefed/user'],
        password: user_config['/piefed/password'],
        community: user_config['/piefed/community'],
      )
      return @piefed
    rescue => e
      e.log(acct: acct.to_s)
      return nil
    end

    def annict
      return nil unless [:token].all? {|k| user_config["/annict/#{k}"]}
      @annict ||= AnnictService.new(user_config['/annict/token'], guest: bot?)
      return @annict
    end

    def featured_tags
      return TagContainer.new
    end

    def followed_tags
      return TagContainer.new
    end

    def field_tags
      tags = TagContainer.new
      tags.merge(fields.map {|v| v['value']}.select {|v| v.start_with?('#')})
      return tags
    rescue => e
      e.log(acct: acct.to_s)
      return TagContainer.new
    end

    def bio_tags
      return TagContainer.scan(bio)
    rescue => e
      e.log(acct: acct.to_s)
      return TagContainer.new
    end

    def notify_verbose?
      return user_config['/notify/verbose'] == true
    end

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return user_config["/handler/#{handler.underscore}/disable"] == true rescue false
    end

    def user_tags
      return user_config.tags
    end

    alias tags user_tags

    def disabled_tags
      dic = TaggingDictionary.new.cache
      tags = TagContainer.new
      (user_config['/tagging/tags/disabled'] || []).each do |tag|
        tags.add(tag)
        tags.merge(dic[tag][:words])
      end
      return tags
    rescue => e
      e.log(acct: acct.to_s)
    end

    def attachments
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def clear_attachments(params = {})
      raise Ginseng::AuthError, 'Only test users can run it' unless test?
      bar = ProgressBar.create(total: status_delete_limit)
      attachments.first(status_delete_limit).each do |attachment|
        service.delete_attachment(attachment)
      rescue => e
        e.log(acct: acct.to_s)
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def default_scopes
      return controller_class.oauth_scopes(:infobot) if info?
      return controller_class.oauth_scopes
    end

    def status_delete_limit
      return controller_class.status_delete_limit || attachments.count
    end

    def test?
      return true if account_class.test_account&.id == id
      return true if username == config['/agent/test/username']
      return false
    rescue => e
      e.log
      return false
    end

    def info?
      return true if account_class.info_account&.id == id
      return true if username == config['/agent/info/username']
      return false
    rescue => e
      e.log
      return false
    end

    def to_h
      return values.deep_symbolize_keys.merge(
        acct: acct.to_s,
        roles: roles.map(&:to_h),
        display_name:,
        is_admin: admin?,
        is_info_bot: info?,
        is_test_bot: test?,
        url: uri.to_s,
        username:,
      ).compact
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def test_token
        return config['/agent/test/token'].decrypt
      rescue Ginseng::ConfigError
        return nil
      rescue
        return config['/agent/test/token']
      end

      def test_account
        return nil unless test_token
        return Environment.account_class.get(token: test_token)
      rescue => e
        e.log
        return nil
      end

      def info_token
        return config['/agent/info/token'].decrypt
      rescue Ginseng::ConfigError
        return nil
      rescue
        return config['/agent/info/token']
      end

      def info_account
        return nil unless info_token
        return Environment.account_class.get(token: info_token)
      rescue => e
        e.log
        return nil
      end
    end
  end
end
