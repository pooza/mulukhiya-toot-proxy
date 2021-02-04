module Mulukhiya
  class MediaAtomFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = "#{@sns.info['metadata']['nodeName']} メディアファイル"
      @channel[:description] = "#{@sns.info['metadata']['nodeName']} メディアファイル"
      fetch
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
