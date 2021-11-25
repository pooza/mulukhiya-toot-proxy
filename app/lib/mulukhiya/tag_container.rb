module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    include Package

    def self.scan(text)
      return TagContainer.new(
        text.scan(Ginseng::Fediverse::Parser.hashtag_pattern).map(&:first),
      )
    end

    def self.default_tags
      return DefaultTagHandler.tags
    end

    def self.remote_default_tags
      return DefaultTagHandler.remote_tags
    end

    def self.media_tag?
      return Handler.create('media_tag').disable? == false
    end

    def self.media_tags
      return MediaTagHandler.all.values
    end
  end
end
