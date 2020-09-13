require 'twitter'

module Mulukhiya
  class TwitterService < Twitter::REST::Client
    alias tweet update

    def create_status(params)
      tweet = TweetString.new(params['spoiler_text']) if params['spoiler_text'].present?
      tweet ||= TweetString.new(params['status'])
      tweet.account = Environment.account_class[params['account_id']] if params['account_id']
      status = [tweet.tweetablize]
      status.push(tweet.extra_tags.join(' ')) if tweet.extra_tags.present?
      status.push(params['url'])
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
