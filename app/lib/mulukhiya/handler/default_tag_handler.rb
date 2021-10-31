module Mulukhiya
  class DefaultTagHandler < TagHandler
    def addition_tags
      return DefaultTagHandler.tags
    end

    def self.tags
      return TagContainer.new((config['/tagging/default_tags'] rescue []))
    end
  end
end
