module Mulukhiya
  class RSS20FeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods
    attr_accessor :command, :storage

    def initialize(channel = {})
      super
      @http.retry_limit = 1
      @sns = sns_class.new
      @channel[:author] = @sns.maintainer_name
      @storage = RenderStorage.new
    end

    def cache
      raise Ginseng::NotFoundError, 'Not Found' unless command
      command.exec
      raise command.stderr unless command.status.zero?
      self.entries = JSON.parse(command.stdout)
      storage[command] = feed.to_s
    end

    alias save cache

    def clear
      storage.del(command)
    end

    def to_s
      return feed.to_s unless storage.key?(command)
      return storage[command]
    rescue => e
      logger.error(error: e)
      return feed.to_s
    end

    private

    def fetch_image(uri)
      return nil unless uri
      return storage[uri] if storage.key?(uri)
      return storage[uri] = super
    rescue => e
      logger.error(error: e)
      return super
    end
  end
end
