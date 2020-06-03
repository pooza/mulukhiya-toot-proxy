module Mulukhiya
  class TweetWorker
    include Sidekiq::Worker

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.twitter
      account.twitter.tweet(create_status(params['status']))
    end

    def create_status(source)
      return source
    end
  end
end
