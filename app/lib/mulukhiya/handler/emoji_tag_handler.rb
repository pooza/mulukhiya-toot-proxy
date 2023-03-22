module Mulukhiya
  class EmojiTagHandler < TagHandler
    def disable?
      return super
    end

    def addition_tags
      logger.info(payload:)
      return TaggingDictionary.new()
    end

    def all(&block)
      return enum_for(__method__) unless block
      handler_config(:dic).each(&block)
    end
  end
end
