module Mulukhiya
  class TweetWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
    end

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.twitter
      account.twitter.tweet(create_status(params))
    end

    private

    def create_status(params)
      if params['spoiler_text'].present?
        status = TweetString.new(params['spoiler_text'])
      else
        status = TweetString.new(params['status'])
      end
      return [status.tweetablize(length), params['url']].join("\n")
    end

    def length
      return @config['/twitter/status/length/max'] - @config['/twitter/status/length/url'] - 1
    end
  end
end
