require 'twitter-text'

module Mulukhiya
  class TweetWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
    end

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.twitter
      status = create_status(params)
      raise "Invalid tweet string '#{status}'" unless status.valid?
      account.twitter.tweet(status)
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
      return TweetString.new(status.join("\n"))
    end

    def create_tags(params, status = nil)
      status || params['status']
      exist_tags = Twitter::TwitterText::Extractor.extract_hashtags(status)
      tags = default_tags
      tags.push('実況') if params['livecure']
      tags.uniq!
      tags = tags.delete_if {|t| exist_tags.member?(t)}
      return tags.map {|t| Ginseng::Fediverse::Service.create_tag(t)}
    end

    def default_tags
      return @config['/twitter/status/tags']
    rescue Ginseng::ConfigError
      return []
    end

    def create_max_length(params)
      suffixes = ['あ' * @config['/twitter/status/length/url']]
      suffixes.concat(default_tags.map {|t| Ginseng::Fediverse::Service.create_tag(t)})
      suffixes.push('#実況') if params['livecure']
      suffixes_length = TweetString.new(suffixes.join(' ')).length.ceil
      return @config['/twitter/status/length/max'] - suffixes_length
    end
  end
end
