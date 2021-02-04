module Mulukhiya
  class MediaFeedRenderer < Ginseng::Web::FeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = "#{@sns.info['metadata']['nodeName']} メディアファイル"
      @channel[:description] = "#{@sns.info['metadata']['nodeName']} メディアファイル"
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
  end
end
