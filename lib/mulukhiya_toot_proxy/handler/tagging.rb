module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      keys = []
      dictionary.each do |key, pattern|
        next if key.length < @config['/tagging/word/minimum_length']
        tag = Mastodon.create_tag(key.gsub(/[\s　]/, ''))
        next if body['status'].include?(tag)
        if pattern.is_a?(Regexp)
          next unless body['status'] =~ pattern
        else
          next unless body['status'].include?(pattern)
        end
        keys.delete_if{|v| key.include?(v[:key])}
        keys.delete_if{|v| v[:key].include?(key)}
        keys.push({tag: tag, key: key})
        increment!
      end
      body['status'] = "#{body['status']}\n#{keys.map{|v| v[:tag]}.join(' ')}" if keys.present?
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
