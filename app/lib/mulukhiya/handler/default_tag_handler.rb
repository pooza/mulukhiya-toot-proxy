module Mulukhiya
  class DefaultTagHandler < TagHandler
    def additional_tags
      return TagContainer.default_tags
    end
  end
end
