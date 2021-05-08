module Mulukhiya
  class AtomFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = channel['title']
      @channel[:description] = channel['description']
    end

    def entries=(entries)
      entries.each {|v| push(v)}
    end
  end
end
