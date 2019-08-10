require 'unicode'
require 'digest/sha1'

module MulukhiyaTootProxy
  class TagContainer < Array
    attr_reader :body

    def push(word)
      @tags = nil
      super(word.sub(/^#/, ''))
    end

    def concat(words)
      words.map{|v| push(v)} if words.is_a?(Array)
    end

    def body=(body)
      @tags = nil
      @body = Unicode.nfkc(body)
    end

    def count
      return create_tags.count
    end

    def to_s
      return create_tags.join(' ')
    end

    def create_tags
      unless @tags
        @tags = map do |tag|
          tag.gsub!(/\s/, '') unless tag =~ /^[a-z0-9\s]+$/i
          Mastodon.create_tag(tag)
        end
        @tags.uniq!
        @tags.compact!
        @tags.delete_if{|v| @body =~ create_pattern(v)} if @body
      end
      return @tags
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

    def self.tweak(body)
      links = {}
      source = body.clone
      source.scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        key = Digest::SHA1.hexdigest(link)
        links[key] = link
        body.sub!(link, key)
      end
      body.gsub!(/ *#/, ' #')
      body.sub!(/^ #/, '#')
      links.each do |key, link|
        body.sub!(key, link)
      end
      return body
    end

    private

    def create_pattern(tag)
      tag = Mastodon.create_tag(tag) unless tag =~ /^#/
      return Regexp.new("#{tag}([^[:word:]]|$)")
    end
  end
end
