module Mulukhiya
  class RSS20FeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
    end

    private

    def fetch_image(uri)
      return nil unless uri
      uri = Ginseng::URI.parse(uri.to_s)
      storage.push(uri) unless storage[uri]
      values = storage[uri]
      return {
        url: uri.to_s,
        type: values[:type],
        length: values[:size],
      }
    rescue => e
      logger.error(error: e, uri: uri.to_s)
      return nil
    end

    def storage
      @storage = MediaMetadataStorage.new
      return @storage
    end
  end
end
