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

    def create_status(params)
      if params['spoiler_text'].present?
        status = TweetString.new(params['spoiler_text'])
      else
        status = TweetString.new(params['status'])
      end
      status = [status.ellipsize(TweetString.max_length)]
      status.push(TweetString.tags.join(' ')) if TweetString.tags.present?
      status.push(params['url'])
      return status.join("\n")
    end
  end
end
