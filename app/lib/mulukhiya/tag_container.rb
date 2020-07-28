module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    def initialize
      super
      @config = Config.instance
      concat(default_tags)
    end

    def default_tags
      return TagContainer.default_tags
    end

    def self.default_tags
      return @config['/tagging/default_tags'].map do |tag|
        Environment.sns_class.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end
  end
end
