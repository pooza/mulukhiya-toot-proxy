require 'twitter'

module Mulukhiya
  class TwitterService < Twitter::REST::Client
    alias tweet update

    def create_status(params)
      text = TweetString.new(params['spoiler_text']) if params['spoiler_text'].present?
      text ||= TweetString.new(params['status'])
      status = [text.tweetablize, params['url']]
      status.push(text.extra_tags.join(' ')) if text.extra_tags.present?
      return TweetString.new(status.join("\n"))
    end

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
