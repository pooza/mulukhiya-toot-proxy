module Mulukhiya
  class CustomAPI
    include Package
    include SNSMethods
    attr_reader :params

    def initialize(params = {})
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
      return File.join('/mulukhiya/api', params[:path])
    end

    def dir
      return params[:dir]
    end

    def args
      return params[:command].select {|v| v.is_a?(Symbol)}
    end

    def args?
      return args.present?
    end

    def choices(key)
      sns = sns_class.new
      uri = sns.create_uri(params.dig(:choices, key))
      return sns.http.get(uri).parsed_response
    rescue => e
      e.log(key:)
      return []
    end

    def description
      return params[:description]
    end

    def to_h
      return params.merge(
        id:,
        fullpath:,
        args:,
      )
    end

    def create_command(args = {})
      command = CommandLine.create(params)
      command.args.push(args[command.args.pop]) if command.args.last.is_a?(Symbol)
      command.env['RUBYOPT'] = '--disable-did_you_mean' if config['/bundler/did_you_mean']
      return command
    end

    def storage
      @storage ||= CustomAPIRenderStorage.new
      return @storage
    end

    def create_renderer(args = {})
      key = params.merge(args:)
      unless storage[key]
        command = create_command(args)
        command.exec
        raise Ginseng::RequestError, command.stderr unless command.status.zero?
        storage[key] = command.response
      end
      cache = storage[key]
      renderer = Ginseng::Web::RawRenderer.new
      renderer.type = cache[:type]
      renderer.body = cache[:body]
      return renderer
    rescue => e
      renderer = Ginseng::Web::JSONRenderer.new
      renderer.message = {message: e.message}
      renderer.status = e.status
      return renderer
    end

    def self.present?
      return config['/api/custom'].present?
    end

    def self.to_json
      return all.map(&:to_h).to_json
    end

    def self.count
      return all.count
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      config['/api/custom'].map {|v| new(v)}.each(&block)
    end
  end
end
