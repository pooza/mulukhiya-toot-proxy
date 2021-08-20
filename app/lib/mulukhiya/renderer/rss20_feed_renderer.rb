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

    def save
      raise Ginseng::NotFoundError, 'Not Found' unless command
      clear
      command.exec
      self.entries = JSON.parse(command.stdout)
      storage[command] = to_s
    end

    def clear
      storage[command] = nil
    end

    def to_s
      return storage[command] if storage[command].present? rescue super
      return super
    end

    private

    def fetch_image(uri)
      return storage[uri] if storage[uri].present?
      return storage[uri] = super
    rescue => e
      logger.error(error: e)
      return super
    end
  end
end
