module Mulukhiya
  class CustomAPI
    include Singleton
    include Package

    def create(entry)
      command = CommandLine.create(entry)
      command.exec
      raise Ginseng::Error, command.stderr unless command.status.zero?
      renderer = Ginseng::Web::RawRenderer.new
      renderer.type = command.response[:type]
      renderer.body = command.response[:body]
      return @renderer.to_s
    end

    def self.count
      return entries.count
    end

    def self.entries
      return (config['/api/custom'] || []).map do |entry|
        entry.deep_stringify_keys!
        entry['dir'] ||= Environment.dir
        entry['title'] ||= entry['path']
        entry['id'] = entry['path'].to_hashtag_base
        entry
      end
    end

    private

    def initialize
    end
  end
end
