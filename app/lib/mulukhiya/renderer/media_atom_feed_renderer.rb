module Mulukhiya
  class MediaAtomFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = Environment.sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = "#{@sns.info['metadata']['nodeName']} 直近のメディアファイル"
      @channel[:description] = "#{@sns.info['metadata']['nodeName']} 直近のメディアファイル #{limit}件"
      fetch
    end

    private

    def params
      return {limit: limit}
    end

    def limit
      return config['/feed/media/limit']
    end

    def fetch
      entries.clear
      return nil unless controller_class.media_catalog?
      Environment.attachment_class.feed do |row|
        push(row)
      end
      @atom = nil
    end
  end
end
