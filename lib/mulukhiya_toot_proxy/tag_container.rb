module MulukhiyaTootProxy
  class TagContainer < Array
    attr_accessor :body

    def push(word)
      delete_if{|v| word.include?(v) || v.include?(word)}
      super(word)
    end

    def concat(values)
      values.each do |v|
        push(v)
      end
    end

    def create_tags
      tags = map{|v| Mastodon.create_tag(v.gsub(/[\s　]/, ''))}
      tags = tags.concat(TagContainer.default_tags)
      tags.uniq!
      tags.compact!
      tags.delete_if{|v| @body =~ create_pattern(v)} if @body
      return tags
    end

    def self.default_tags
      return Config.instance['/tagging/default_tags'].map do |tag|
        Mastodon.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end

    def self.scan(body)
      pattern = Regexp.new(Config.instance['/mastodon/hashtag/pattern'], Regexp::IGNORECASE)
      return body.scan(pattern).map(&:first)
    end

    private

    def create_pattern(tag)
      tag = Mastodon.create_tag(tag) unless tag =~ /^#/
      return Regexp.new("#{tag}([^[:word:]]|$)")
    end
  end
end
