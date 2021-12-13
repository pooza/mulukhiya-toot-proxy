module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    include Package

    def normalize(word)
      if rule = config['/tagging/normalize/rules'].find {|v| v['source'] == word.to_hashtag_base}
        word = rule['normalized']
      end
      return super
    end

    def self.scan(text)
      return TagContainer.new(
        text.scan(Ginseng::Fediverse::Parser.hashtag_pattern).map(&:first),
      )
    end

    def self.default_tags
      return DefaultTagHandler.tags
    end

    def self.remote_default_tags
      return RemoteTagHandler.tags
    end

    def self.media_tags
      return TagContainer.new(Handler.create('media_tag').all.to_h.values)
    end
  end
end
