module Mulukhiya
  class DefaultTagHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      tags.text = @status
      tags.merge(default_tags)
      result.push(tags: default_tags)
    end

    private

    def default_tags
      return TagContainer.default_tags
    end
  end
end
