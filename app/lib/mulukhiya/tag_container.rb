module Mulukhiya
  class TagContainer < Ginseng::TagContainer
    def self.default_tags
      return Config.instance['/tagging/default_tags'].map do |tag|
        Environment.sns_class.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end
  end
end
