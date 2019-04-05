require 'unicode'

module MulukhiyaTootProxy
  class TagContainer < Array
    attr_reader :body

    def push(word)
      super(word.sub(/^#/, ''))
    end

    def concat(words)
      words.map{|v| push(v)}
    end

    def body=(body)
      @body = Unicode.nfkc(body)
    end

    def count
      return create_tags.count
    end

    def to_s
      return create_tags.join(' ')
    end

    def create_tags
      tags = map{|v| Mastodon.create_tag(v.gsub(/[\s　]/, ''))}
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
