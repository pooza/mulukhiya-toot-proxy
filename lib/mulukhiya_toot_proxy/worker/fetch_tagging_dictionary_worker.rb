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
      return File.join(Environment.dir, 'tmp/cache/tagging_dic')
    end

    private

    def patterns
      r = {}
      @config['/tagging/dictionaries'].each do |dic|
        response = HTTParty.get(dic['url']).parsed_response
        raise Ginseng::GatewayError, "'#{dic['url']}' is invalid" unless response.is_a?(Array)
        raise Ginseng::GatewayError, "'#{dic['url']}' is empty" unless response.present?
        response.each do |entry|
          dic['fields'].each do |field|
            next unless word = entry[field]
            r[word] = create_pattern(word) unless r[word].present?
          rescue => e
            message = e.to_h.clone
            message['dictionary'] = dic
            @logger.error(message)
            next
          end
        end
      end
      return r
    end

    def create_pattern(word)
      return Regexp.new(word.gsub(' ', '[\s　]?')) if word.include?(' ')
      return word
    end
  end
end
