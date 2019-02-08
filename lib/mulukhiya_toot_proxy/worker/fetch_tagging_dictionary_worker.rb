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
    end

    def self.cache_path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end

    private

    def patterns
      r = {}
      @config['/tagging/dictionaries'].each do |dictionary|
        HTTParty.get(dictionary['url']).parsed_response.each do |entry|
          dictionary['fields'].each do |field|
            next unless word = entry[field]
            r[word] = create_pattern(word) unless r[word].present?
          rescue => e
            @logger.error("#{dictionary} #{e.message}")
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
