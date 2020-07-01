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

      alias to_h values

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

      def twitter
        return nil
      end

      def self.[](id)
        return Account.new(id)
      end

      def self.get(key)
        if acct = key[:acct]
        elsif key.key?(:token)
          return nil if key[:token].nil?
          entry = collection.find(token: key[:token]).first
          return Account.new(entry['_id']) if entry
          return AccessToken.get(hash: key[:token]).account
        end
      end

      def self.collection
        return Mongo.instance.db[:users]
      end
    end
  end
end
