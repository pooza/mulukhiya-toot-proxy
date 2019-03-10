module MulukhiyaTootProxy
  class TagContainer < Array
    attr_accessor :body

    def push(word)
      delete_if{|v| word.include?(v) || v.include?(word)}
      super(word)
    end

    def create_tags
      tags = map{|v| Mastodon.create_tag(v.gsub(/[\s　]/, ''))}
      tags = tags.concat(TagContainer.default_tags)
      tags.uniq!
      tags.delete_if{|v| @body =~ TagContainer.create_pattern(v)} if @body
      return tags
    end

    def self.default_tags
      return Config.instance['/tagging/default_tags'].map do |tag|
        Mastodon.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end

    def self.create_pattern(tag)
      tag = Mastodon.create_tag(tag) unless tag =~ /^#/
      return Regexp.new("#{tag}([^[:word:]]|$)")
    end
  end
end
