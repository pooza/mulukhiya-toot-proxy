module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    def initialize
      super
      @config = Config.instance
      concat(default_tags)
    end

    def self.default_tags
      return Config.instance['/tagging/default_tags'].map do |tag|
        Environment.sns_class.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end

    def self.default_tag_bases
      return Config.instance['/tagging/default_tags'].map do |tag|
        Environment.sns_class.create_tag_base(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end

    private

    def default_tags
      return TagContainer.default_tags
    end

    def default_tag_bases
      return TagContainer.default_tag_bases
    end
  end
end
