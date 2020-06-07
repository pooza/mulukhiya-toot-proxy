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
      status.ellipsize!(create_max_length(params))
      tags = create_tags(params, status)
      status = [status]
      status.push(tags.join(' ')) if tags.present?
      status.push(params['url'])
      return status.join("\n")
    end

    def create_tags(params, status = nil)
      parser = Ginseng::Fediverse::Parser.new(status || params['status'])
      tags = TweetString.tags
      tags.push('#実況') if params['livecure']
      tags = tags.delete_if do |tag|
        parser.tags.map {|t| MastodonService.create_tag(t)}.member?(tag)
      end
      return tags.uniq
    end

    def create_max_length(params)
      length = TweetString.max_length
      length -= 3 if params['livecure']
      return length
    end
  end
end
