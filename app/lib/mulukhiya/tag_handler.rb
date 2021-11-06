module Mulukhiya
  class TagHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless executable?
      tags.merge(addition_tags)
      tags.reject! {|v| removal_tags.member?(v)}
      result.push(addition_tags: addition_tags, removal_tags: removal_tags)
    end

    def executable?
      return false if parser.command?
      return false if parser.accts.any?(&:agent?)
      return true if payload[visibility_field].empty?
      return true if payload[visibility_field] == controller_class.visibility_name(:public)
      return false
    end

    def removal_tags
      return TagContainer.new
    end

    def addition_tags
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
