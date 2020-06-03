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
      return [
        source.ellipsize(@config['/twitter/status/max_length'] - tags.join(' ').length - 1),
        tags.join(' '),
      ].join("\n")
    end

    def tags
      return @config['/twitter/tweet/tags'].map do |tag|
        MastodonService.create_tag(tag)
      end
    end
  end
end
