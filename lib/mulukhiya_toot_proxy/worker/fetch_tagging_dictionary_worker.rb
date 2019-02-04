require 'httparty'

module MulukhiyaTootProxy
  class FetchTaggingDictionaryWorker
    include Sidekiq::Worker

    def perform
      @config = Config.instance
      File.write(FetchTaggingDictionaryWorker.cache_path, Marshal.dump(patterns))
    end

    def self.cache_path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end

    private

    def patterns
      r = {}
      HTTParty.get(@config['/tagging/dictionary/url']).parsed_response.each do |entry|
        @config['/tagging/dictionary/fields'].each do |field|
          next unless word = entry[field]
          if word.include?(' ')
            r[word] = Regexp.new(word.gsub(' ', '[\s　]?'))
          else
            r[word] = word
          end
        end
      rescue
        next
      end
      return r
    end
  end
end
