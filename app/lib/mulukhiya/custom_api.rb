module Mulukhiya
  class CustomAPI
    include Package
    attr_reader :params

    def initialize(params)
      @params = params.deep_symbolize_keys
      @params[:dir] ||= Environment.dir
    end

    def id
      return path.to_hashtag_base
    end

    def path
      return File.join('/', params[:path])
    end

    def fullpath
      return File.join('/mulukhiya/api', params[:path])
    end

    def args
      return params[:command].select {|v| v.is_a?(Symbol)}
    end

    def args?
      return args.present?
    end

    def description
      return params[:description]
    end

    def to_h
      return params.merge(
        id: id,
        fullpath: fullpath,
        args: args,
      )
    end

    def create_command(args = {})
      command = CommandLine.create(params)
      command.args.push(args[command.args.pop]) if command.args.last.is_a?(Symbol)
      return command
    end

    def create_renderer(args = {})
      command = create_command(args)
      command.exec
      raise Ginseng::RequestError, command.stderr unless command.status.zero?
      renderer = Ginseng::Web::RawRenderer.new
      renderer.type = command.response[:type]
      renderer.body = command.response[:body]
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

    def self.all
      return enum_for(__method__) unless block_given?
      config['/api/custom'].each do |entry|
        yield CustomAPI.new(entry)
      rescue => e
        logger.error(error: e, api: entry)
      end
    end
  end
end
