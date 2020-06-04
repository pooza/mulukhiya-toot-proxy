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
      status = [status.tweetablize(length)]
      status.push(tags.join(' ')) if tags.present?
      status.push(params['url'])
      return status.join("\n")
    end

    def length
      length = @config['/twitter/status/length/max']
      length = length - @config['/twitter/status/length/url'] - 1
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end

    def tags
      @tags ||= @config['/twitter/status/tags'].map {|tag| MastodonService.create_tag(tag)}
      return @tags
    rescue
      return []
    end
  end
end
