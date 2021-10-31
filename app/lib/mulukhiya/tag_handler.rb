module Mulukhiya
  class TagHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      tags.text = @status
      tags.merge(additional_tags)
      tags.reject! {|v| removal_tags.member?(v)}
      result.push(tags: additional_tags)
    end

    def removal_tags
      return TagContainer.new
    end

    def additional_tags
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
