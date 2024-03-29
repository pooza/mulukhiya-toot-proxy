module Mulukhiya
  class MediaFeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.maintainer_name
      @channel[:title] = "#{@sns.node_name} メディアファイル"
      @channel[:description] = "#{@sns.node_name} メディアファイル"
    end

    def to_s
      fetch
      return super
    end

    def fetch
      entries.clear
      return nil unless controller_class.media_catalog?
      attachment_class.feed do |row|
        push(row)
      end
    end

    def self.uri
      return sns_class.new.create_uri('/mulukhiya/feed/media')
    end

    def self.limit
      return config['/feed/media/limit']
    end
  end
end
