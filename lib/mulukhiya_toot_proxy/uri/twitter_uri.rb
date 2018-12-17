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
      raise ExternalServiceError, "Tweet '#{self}' not found" unless tweet
      template = Template.new('tweet_clipping.md')
      template[:account_name] = account_name
      template[:status] = tweet.text
      template[:url] = to_s
      return template.to_s
    end

    def service
      @service ||= TwitterService.new
      return @service
    end
  end
end
