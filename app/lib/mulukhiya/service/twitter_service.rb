require 'twitter'

module Mulukhiya
  class TwitterService < Twitter::REST::Client
    include Package

    alias tweet update

    def self.consumer_key
      return config['/twitter/consumer/key']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.consumer_secret
      return config['/twitter/consumer/secret']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
      return consumer_key.present? && consumer_secret.present?
    end
  end
end
