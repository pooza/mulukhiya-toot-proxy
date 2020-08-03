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
      return consumer_key.present? && consumer_secret.present?
    end
  end
end
