module Mulukhiya
  class RSS20FeedRenderer < Ginseng::Web::RSS20FeedRenderer
    include Package
    include SNSMethods
    attr_accessor :command, :render_storage, :metadata_storage

    def initialize(channel = {})
      super
      @http.retry_limit = 1
      @sns = sns_class.new
      @channel[:author] = @sns.maintainer_name
      @render_storage = RenderStorage.new
      @render_storage.ttl = config['/feed/cache/ttl']
      @metadata_storage = MediaMetadataStorage.new
    end

    def cache
      raise Ginseng::NotFoundError, 'Not Found' unless command
      command.exec
      raise command.stderr unless command.status.zero?
      self.entries = JSON.parse(command.stdout)
      render_storage[command] = feed.to_s
    end

    alias save cache

    def clear
      render_storage.unlink(command)
    end

    def to_s
      return feed.to_s unless render_storage.key?(command)
      return render_storage[command]
    rescue => e
      e.log
      return feed.to_s
    end

    private

    def fetch_image(uri)
      return nil unless uri
      metadata_storage.push(uri) unless metadata_storage.key?(uri)
      return metadata_storage[uri]
    rescue => e
      e.log
      return nil
    end
  end
end
