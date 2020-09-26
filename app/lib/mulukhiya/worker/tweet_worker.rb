module Mulukhiya
  class TweetWorker
    include Sidekiq::Worker
    sidekiq_options retry: 3

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.twitter
      status = account.twitter.create_status(params)
      raise "Invalid tweet string '#{status}'" unless status.valid?
      account.twitter.tweet(status)
    end
  end
end
