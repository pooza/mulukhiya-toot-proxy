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
      return enum_for(__method__) unless block_given?
      Postgres.instance.execute('featured_tags').each do |row|
        yield row['tag']
      end
    end

    def self.media_tag?
      return config['/tagging/media/enable']
    end

    def self.media_tag_bases
      return enum_for(__method__) unless block_given?
      return unless media_tag?
      ['image', 'video', 'audio'].freeze.each do |tag|
        yield config["/tagging/media/tags/#{tag}"]
      end
    end
  end
end
