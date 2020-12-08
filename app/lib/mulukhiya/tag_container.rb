module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    def self.config
      return Config.instance
    end

    def self.default_tags
      return config['/tagging/default_tags'].map(&:to_hashtag)
    rescue Ginseng::ConfigError
      return []
    end

    def self.default_tag_bases
      return config['/tagging/default_tags'].map(&:to_hashtag_base)
    rescue Ginseng::ConfigError
      return []
    end

    def self.futured_tag_bases
      return Environment.hashtag_class.featured_tag_base
    rescue
      return []
    end

    def self.media_tag?
      return config['/tagging/media/enable']
    end

    def self.media_tag_bases
      return [] unless media_tag?
      return ['image', 'video', 'audio'].freeze.map do |tag|
        config["/tagging/media/tags/#{tag}"].to_hashtag_base
      end
    rescue
      return []
    end
  end
end
