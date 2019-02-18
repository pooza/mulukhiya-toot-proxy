require 'httparty'

module MulukhiyaTootProxy
  class FetchTaggingDictionaryWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
      @logger = Logger.new
    end

    def perform
      File.write(FetchTaggingDictionaryWorker.cache_path, Marshal.dump(patterns))
    rescue => e
      e = Ginseng::Error.create(e)
      Slack.broadcast(e.to_h)
      @logger.error(e.to_h)
    end

    def self.cache_path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end

    private

    def patterns
      r = {}
      @config['/tagging/dictionaries'].each do |dic|
        fetch(dic['url']).each do |entry|
          dic['fields'].each do |field|
            next unless word = entry[field]
            r[word] = create_pattern(word) unless r[word].present?
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
      pattern = nil
      pattern = (pattern || word).gsub(/[^[:alnum:]]/, '.?') if word =~ /[^[:alnum:]]/
      return word if pattern.nil?
      return Regexp.new(pattern)
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
  end
end
