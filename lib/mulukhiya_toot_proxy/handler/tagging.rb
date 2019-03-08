module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      keys = []
      TaggingDictionary.new.each do |key, pattern|
        next if key.length < @config['/tagging/word/minimum_length']
        tag = Mastodon.create_tag(key.gsub(/[\s　]/, ''))
        next if body['status'] =~ Regexp.new("#{tag}([^[:word:]]|$)")
        next unless body['status'] =~ pattern
        keys.delete_if{|v| key.include?(v[:key])}
        keys.delete_if{|v| v[:key].include?(key)}
        keys.push({tag: tag, key: key})
      end
      tags = keys.map{|v| v[:tag]}.concat(default_tags).uniq
      @count += tags.count
      body['status'] = "#{body['status']}\n#{tags.join(' ')}" if tags.present?
      return body
    end

    def default_tags
      return @config['/tagging/default_tags'].map do |tag|
        Mastodon.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end
  end
end
