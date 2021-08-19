module Mulukhiya
  class CustomAPI
    include Singleton
    include Package

    def self.count
      return entries.count
    end

    def self.entries
      return (config['/api/custom'] || []).map do |entry|
        entry.deep_stringify_keys!
        entry['dir'] ||= File.join(Environment.dir, 'bin')
        entry['title'] ||= entry['path']
        entry['id'] = entry['path'].tr('/', '_')
        entry
      end
    end

    private

    def initialize
    end
  end
end
