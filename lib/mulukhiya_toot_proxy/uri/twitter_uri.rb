module MulukhiyaTootProxy
  class TwitterURI < Ginseng::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
    end

    def twitter?
      return host == 'twitter.com'
    end

    def tweet_id
      return nil unless twitter?
      return nil unless matches = path.match(Regexp.new(@config['/twitter/patterns/tweet']))
      return matches[2].to_i
    end

    alias id tweet_id

    def account_name
      return nil unless matches = path.match(Regexp.new(@config['/twitter/patterns/tweet']))
      return matches[1]
    end

    def to_md
      tweet = service.lookup_tweet(tweet_id)
      raise Ginseng::GatewayError, "Tweet '#{self}' not found" unless tweet
      template = Template.new('tweet_clipping.md')
      template[:account_name] = account_name
      template[:status] = tweet.text
      template[:url] = to_s
      return template.to_s
    rescue Twitter::Error::NotFound
      raise Ginseng::GatewayError, "Tweet '#{self}' not found"
    end

    def service
      @service ||= TwitterService.new
      return @service
    end
  end
end
