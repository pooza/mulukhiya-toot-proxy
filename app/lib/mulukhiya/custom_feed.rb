module Mulukhiya
  class CustomFeed
    include Package
    include SNSMethods
    attr_reader :params

    def initialize(params)
      @params = params.deep_symbolize_keys
      @params[:dir] ||= Environment.dir
    end

    def id
      return path.to_hashtag_base
    end

    def uri
      @uri ||= sns_class.new.create_uri(fullpath)
      return @uri
    end

    def path
      return File.join('/', params[:path])
    end

    def fullpath
      return File.join('/mulukhiya/feed', params[:path])
    end

    def dir
      return @params[:dir]
    end

    def title
      return params[:title] || path
    end

    def update
      renderer.cache
    end

    def command
      unless @command
        @command = CommandLine.create(params)
        @command.env['RUBYOPT'] = '--disable-did_you_mean' if config['/bundler/did_you_mean']
      end
      return @command
    end

    def renderer
      unless @renderer
        @renderer = RSS20FeedRenderer.new(params)
        @renderer.command = command
      end
      return @renderer
    end

    def self.count
      return all.count
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      config['/feed/custom'].map {|v| new(v)}.each(&block)
    end
  end
end
