module Mulukhiya
  module Meisskey
    class Account < CollectionModel
      def to_h
        unless @hash
          @hash = values.clone
          @hash[:url] = uri.to_s
          @hash.delete('password')
          @hash.compact!
        end
        return @hash
      end

      def acct
        @acct ||= Acct.new("@#{username}@#{host || Environment.domain_name}")
        return @acct
      end

      def uri
        unless @uri
          if host
            @uri = NoteURI.parse("https://#{host}")
          else
            @uri = NoteURI.parse(Config.instance['/meisskey/url'])
          end
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      alias admin? isAdmin

      def moderator?
        return false
      end

      alias bot? isBot

      alias locked? isLocked

      def notify_verbose?
        return config['/notify/verbose'] == true
      end

      def disable?(handler_name)
        return true if config["/handler/#{handler_name}/disable"]
        return false
      end

      def tags
        return config['/tags'] || []
      end

      def config
        @config ||= UserConfig.new(id)
        return @config
      end

      def webhook
        return Webhook.new(config)
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

      def twitter
        unless @twitter
          return nil unless config['/twitter/token']
          return nil unless config['/twitter/secret']
          @twitter = TwitterService.new do |twitter|
            twitter.consumer_key = TwitterService.consumer_key
            twitter.consumer_secret = TwitterService.consumer_secret
            twitter.access_token = config['/twitter/token']
            twitter.access_token_secret = config['/twitter/secret']
          end
        end
        return @twitter
      rescue => e
        @logger.error(e)
        return nil
      end

      def self.[](id)
        return Account.new(id)
      end

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          entry = collection.find(username: acct.username, host: acct.domain).first
          return Account.new(entry['_id']) if entry
          return nil
        elsif key.key?(:token)
          return nil if key[:token].nil?
          entry = collection.find(token: key[:token]).first
          return Account.new(entry['_id']) if entry
          return AccessToken.get(hash: key[:token]).account
        end
        entry = collection.find(key).first
        return Account.new(entry['_id']) if entry
      end

      def self.first(key)
        return get(key)
      end

      private

      def collection_name
        return :users
      end
    end
  end
end
