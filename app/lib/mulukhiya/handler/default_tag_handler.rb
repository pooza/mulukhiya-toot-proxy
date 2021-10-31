module Mulukhiya
  class DefaultTagHandler < TagHandler
    def addition_tags
      return TagContainer.default_tags
    end
  end
end
