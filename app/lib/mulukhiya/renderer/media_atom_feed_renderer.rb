module Mulukhiya
  class MediaAtomFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package

    def initialize(channel = {})
      super
      @sns = Environment.sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = "#{@sns.info['title']} 直近のメディアファイル"
      @channel[:description] = "#{@sns.info['title']} 直近のメディアファイル #{limit}件"
      fetch
    end

    private

    def params
      return {
        limit: limit,
        test_usernames: @config['/feed/test_usernames'],
      }
    end

    def limit
      return @config['/feed/media/limit']
    end

    def fetch
      entries.clear
      return nil unless Environment.controller_class.media_catalog?
      Environment.attachment_class.feed_entries do |row|
        push(row)
      end
      @atom = nil
    end
  end
end
