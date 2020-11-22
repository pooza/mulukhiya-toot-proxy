module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    def create_tags
      unless @tags
        @tags = map do |tag|
          tag = tag.dup
          tag.gsub!(/\s/, '') unless /^[a-z0-9\s]+$/i.match?(tag)
          tag.to_hashtag
        end
        @tags.uniq!
        @tags.compact!
        @tags.delete_if {|v| @text.match?(create_pattern(v))} if @text
      end
      return @tags
    end

    def self.default_tags
      return Config.instance['/tagging/default_tags'].map(&:to_hashtag)
    rescue Ginseng::ConfigError
      return []
    end

    def self.default_tag_bases
      return Config.instance['/tagging/default_tags'].map(&:to_hashtag_base)
    rescue Ginseng::ConfigError
      return []
    end
  end
end
