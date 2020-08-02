module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    include Package

    def initialize
      super
      @config = Config.instance
      concat(default_tags)
    end

    def self.default_tags
      return config['/tagging/default_tags'].map do |tag|
        Environment.sns_class.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end

    private

    def default_tags
      return TagContainer.default_tags
    end
  end
end
