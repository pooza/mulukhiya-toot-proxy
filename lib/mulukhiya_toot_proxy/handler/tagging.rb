module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      tags = []
      dictionary.each do |k, pattern|
        tag = Mastodon.create_tag(k.gsub(/[\s　]/, ''))
        next if body['status'].include?(tag)
        if pattern.is_a?(Regexp)
          next unless body['status'] =~ pattern
        else
          next unless body['status'].include?(pattern)
        end
        tags.push(tag)
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
