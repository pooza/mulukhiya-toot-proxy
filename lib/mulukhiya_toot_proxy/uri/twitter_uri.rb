require 'addressable/uri'

module MulukhiyaTootProxy
  class TwitterURI < Addressable::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
    end

    def twitter?
      return host == 'twitter.com'
    end

    def tweet_id
      return nil unless matches = path.match(Regexp.new(@config['/twitter/patterns/tweet']))
      return matches[2].to_i
    end

    def account_name
      return nil unless matches = path.match(Regexp.new(@config['/twitter/patterns/tweet']))
      return matches[1]
    end

    def clip(params)
      params[:growi].push({path: params[:path], body: to_md})
    end

    def to_md
      tweet = service.lookup_tweet(tweet_id)
      raise ExternalServiceError, "ツイートが取得できません。 #{self}" unless tweet
      return [
        '## アカウント',
        "[@#{account_name}](https://twitter.com/#{account_name})",
        '## 本文',
        tweet.text,
        '## URL',
        to_s,
      ].join("\n")
    end

    def service
      @service ||= TwitterService.new
      return @service
    end
  end
end
