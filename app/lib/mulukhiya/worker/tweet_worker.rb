module Mulukhiya
  class TweetWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
    end

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.twitter
      account.twitter.tweet(create_status(params['status']))
    end

    private

    def create_status(source)
      status = TweetString.new(source)
      length = @config['/twitter/status/length/max'] - @config['/twitter/status/length/url']
      length = length - 1 - tags.join(' ').length if tags.present?
      status.tweetablize!(length)
      status = [status, tags.join(' ')].join("\n") if tags.present?
      return status
    end

    def tags
      return @config['/twitter/tweet/tags'].map do |tag|
        MastodonService.create_tag(tag)
      end
    end
  end
end
