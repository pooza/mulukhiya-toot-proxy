require 'twitter'

module Mulukhiya
  class TwitterService < Twitter::REST::Client
    alias tweet update

    def self.consumer_key
      return Config.instance['/twitter/consumer/key']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.consumer_secret
      return Config.instance['/twitter/consumer/secret']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
      return false if consumer_key.nil?
      return false if consumer_secret.nil?
      return true
    end
  end
end
