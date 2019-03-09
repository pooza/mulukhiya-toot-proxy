module MulukhiyaTootProxy
  class TaggingDictionary < Hash
    def initialize
      super
      @config = Config.instance
      @logger = Logger.new
      @http = HTTP.new
      update(Marshal.load(File.read(TaggingDictionary.path))) if exist?
    end

    def exist?
      return File.exist?(TaggingDictionary.path)
    end

    def refresh
      File.write(TaggingDictionary.path, Marshal.dump(patterns))
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h)
    end

    alias create refresh

    def delete
      File.unlink(TaggingDictionary.path) if exist?
    end

    def patterns
      r = {}
      resources.each do |resource|
        fetch(resource['url']).each do |entry|
          resource['fields'].each do |field|
            next unless word = entry[field]
            r[word] ||= create_pattern(word)
          rescue => e
            message = Ginseng::Error.create(e).to_h.clone
            message['resource'] = resource
            @logger.error(message)
            next
          end
        end
      end
      return r.sort_by{|k, v| k.length}.to_h
    end

    def create_pattern(word)
      return Regexp.new(word.gsub(/[^[:alnum:]]/, '.?'))
    end

    def resources
      return Config.instance['/tagging/dictionaries']
    rescue
      return []
    end

    def fetch(url)
      response = @http.get(url).parsed_response
      raise 'not array' unless response.is_a?(Array)
      raise 'empty' unless response.present?
      return response
    rescue => e
      raise Ginseng::GatewayError, "'#{url}' is invalid (#{e.message})"
    end

    def self.path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end
  end
end
