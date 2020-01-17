module MulukhiyaTootProxy
  class TagContainer < Ginseng::TagContainer
    def push(word)
      super(word.to_s)
    end

    def self.default_tags
      return Config.instance['/tagging/default_tags'].map do |tag|
        Environment.sns_class.create_tag(tag)
      end
    rescue Ginseng::ConfigError
      return []
    end
  end
end
