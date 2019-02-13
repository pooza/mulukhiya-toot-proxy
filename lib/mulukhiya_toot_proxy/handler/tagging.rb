module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      tags = []
      keys = []
      dictionary.reverse_each do |key, pattern|
        next if key.length < @config['/tagging/word/minimum_length']
        tag = Mastodon.create_tag(key.gsub(/[\s　]/, ''))
        next if body['status'].include?(tag)
        next unless keys.grep(Regexp.new(key)).empty?
        if pattern.is_a?(Regexp)
          next unless body['status'] =~ pattern
        else
          next unless body['status'].include?(pattern)
        end
        tags.push(tag)
        keys.push(key)
        increment!
      end
      body['status'] = "#{body['status']}\n#{tags.join(' ')}" if tags.present?
      return body
    end

    def dictionary
      unless File.exist?(FetchTaggingDictionaryWorker.cache_path)
        FetchTaggingDictionaryWorker.new.perform
      end
      return Marshal.load(File.read(FetchTaggingDictionaryWorker.cache_path))
    end
  end
end
