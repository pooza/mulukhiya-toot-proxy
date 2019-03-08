module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      keys = []
      TaggingDictionary.new.each do |key, pattern|
        next if key.length < @config['/tagging/word/minimum_length']
        tag = Mastodon.create_tag(key.gsub(/[\s　]/, ''))
        next if body['status'] =~ create_pattern(tag)
        next unless body['status'] =~ pattern
        keys.delete_if{|v| key.include?(v[:key])}
        keys.delete_if{|v| v[:key].include?(key)}
        keys.push({tag: tag, key: key})
      end
      tags = keys.map{|v| v[:tag]}.concat(default_tags(body['status'])).uniq
      @count += tags.count
      body['status'] = "#{body['status']}\n#{tags.join(' ')}" if tags.present?
      return body
    end

    def default_tags(body = nil)
      tags = @config['/tagging/default_tags'].map do |tag|
        Mastodon.create_tag(tag)
      end
      tags.delete_if{|v| body =~ create_pattern(v)} if body
      return tags
    rescue Ginseng::ConfigError
      return []
    end

    private

    def create_pattern(tag)
      tag = Mastodon.create_tag(tag) unless tag =~ /^#/
      return Regexp.new("#{tag}([^[:word:]]|$)")
    end
  end
end
