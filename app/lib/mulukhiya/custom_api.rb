module Mulukhiya
  class CustomAPI
    include Singleton
    include Package

    def create(entry, params = {})
      command = CommandLine.create(entry)
      if command.args.last.is_a?(Symbol)
        key = command.args.pop
        command.args.push(params[key])
      end
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

    def self.count
      return entries.count
    end

    def self.entries
      return (config['/api/custom'] || []).map do |entry|
        entry.deep_stringify_keys!
        entry['dir'] ||= Environment.dir
        entry['title'] ||= entry['path']
        entry['params'] = entry['command'].select {|v| v.is_a?(Symbol)}
        entry['id'] = entry['path'].to_hashtag_base
        entry
      end
    end

    private

    def initialize
    end
  end
end
