module Mulukhiya
  class FeedController < Controller
    get '/tag/:tag' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.feed?
      @renderer = TagFeedRenderer.new
      @renderer.tag = params[:tag]
      @renderer.status = 404 unless @renderer.exist?
      return @renderer.to_s
    rescue => e
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.media_catalog?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.feed?
      @renderer = MediaFeedRenderer.new
      return @renderer.to_s
    rescue => e
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    config['/feed/custom'].each do |entry|
      get File.join('/', entry['path']) do
        raise Ginseng::NotFoundError, "Resource #{request.path} not found." unless command
        command.exec
        raise Ginseng::Error, command.stderr unless command.status.zero?
        @renderer = RSS20FeedRenderer.new(entry)
        @renderer.entries = JSON.parse(command.stdout)
        return @renderer.to_s
      rescue => e
        e = Ginseng::Error.create(e)
        @renderer = Ginseng::Web::XMLRenderer.new
        @renderer.status = e.status
        @renderer.message = {error: e.message}
        return @renderer.to_s
      end
    end

    private

    def path_prefix
      return '' if Environment.test?
      return '/mulukhiya/feed'
    end
  end
end
