module Mulukhiya
  module Meisskey
    class Account
      attr_reader :id

      def initialize(id)
        @id = id.to_s
        @logger = Logger.new
      end

      def values
        @values ||= Account.collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
        return @values
      end

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
        @acct ||= Acct.new("@#{values['username']}@#{values['host'] || Environment.domain_name}")
        return @acct
      end

      def uri
        unless @uri
          if values['host']
            @uri = NoteURI.parse("https://#{values['host']}")
          else
            @uri = NoteURI.parse(Config.instance['/meisskey/url'])
          end
          @uri.path = "/@#{values['username']}"
        end
        return @uri
      end

      def admin?
        return values['isAdmin']
      end

      def moderator?
        return false
      end

      def bot?
        return values['isBot']
      end

      def locked?
        return values['isLocked']
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

      def self.collection
        return Mongo.instance.db[:users]
      end
    end
  end
end
