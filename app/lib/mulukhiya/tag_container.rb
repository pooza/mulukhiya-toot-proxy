module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
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
