module Mulukhiya
  class RSS20FeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @channel[:title] = channel['title']
      @channel[:description] = channel['description']
      return unless channel['link']
      @http.base_uri = URI.parse(channel['link'])
      @http.retry_limit = 2
      @channel[:link] = @http.base_uri.to_s
    end

    def self.fix_uri(root, href)
      uri = Ginseng::URI.parse(href.to_s)
      return uri if uri.absolute?
      uri = Ginseng::URI.parse(root.to_s)
      if href.to_s.start_with?('/')
        uri.path = href.to_s
      else
        uri.path = File.expand_path(uri.path, href.to_s)
      end
      return uri
    end
  end
end
