require 'httparty'

module MulukhiyaTootProxy
  class TaggingDictionary < Hash
    def initialize
      super
      @config = Config.instance
      @logger = Logger.new
      create unless exist?
      update(Marshal.load(File.read(TaggingDictionary.path)))
    end

    def exist?
      return File.exist?(TaggingDictionary.path)
    end

    def create
      File.write(TaggingDictionary.path, Marshal.dump(patterns))
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h)
    end

    def delete
      File.unlink(TaggingDictionary.path)
    end

    def patterns
      r = {}
      @config['/tagging/dictionaries'].each do |dic|
        fetch(dic['url']).each do |entry|
          dic['fields'].each do |field|
            next unless word = entry[field]
            r[word] ||= create_pattern(word)
          rescue => e
            message = Ginseng::Error.create(e).to_h.clone
            message['dictionary'] = dic
            @logger.error(message)
            next
          end
        end
      end
      return r
    end

    def create_pattern(word)
      return Regexp.new(word.gsub(/[^[:alnum:]]/, '.?'))
    end

    def fetch(url)
      response = HTTParty.get(url, {
        headers: {'User-Agent' => Package.user_agent},
      }).parsed_response
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
