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
      status.ellipsize!(max_length)
      tags = create_tags(status)
      status = [status]
      status.push(tags.join(' ')) if tags.present?
      status.push(params['url'])
      return TweetString.new(status.join("\n"))
    end

    def create_tags(status)
      exist_tags = Twitter::TwitterText::Extractor.extract_hashtags(status)
      tags = default_tags
      tags = tags.delete_if {|t| exist_tags.member?(t)}
      return tags.map {|t| Ginseng::Fediverse::Service.create_tag(t)}
    end

    def default_tags
      return @config['/twitter/status/tags']
    rescue Ginseng::ConfigError
      return []
    end

    def max_length
      suffixes = [' ', 'あ' * @config['/twitter/status/length/url']]
      suffixes.concat(default_tags.map {|t| Ginseng::Fediverse::Service.create_tag(t)})
      suffixes_length = TweetString.new(suffixes.join('  ')).length.ceil
      return @config['/twitter/status/length/max'] - suffixes_length
    end
  end
end
