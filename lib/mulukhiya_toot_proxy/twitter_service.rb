require 'twitter'

module MulukhiyaTootProxy
  class TwitterService < Twitter::REST::Client
    def initialize
      @config = Config.instance
      super do |config|
        config.consumer_key = @config['/twitter/consumer_key']
        config.consumer_secret = @config['/twitter/consumer_secret']
        config.access_token = @config['/twitter/access_token']
        config.access_token_secret = @config['/twitter/access_token_secret']
        config.user_agent = Package.user_agent
      end
    end

    def tweet(message)
      return update(message)
    end

    def lookup_tweet(id)
      return status(id)
    end
  end
end
