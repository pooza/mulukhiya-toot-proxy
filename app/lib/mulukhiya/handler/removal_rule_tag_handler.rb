module Mulukhiya
  class RemovalRuleTagHandler < TagHandler
    def addition_tags
      return TagContainer.new
    end

    def removal_tags
      return TagContainer.new(@tags)
    end

    def executable?
      return true if rules.any? do |rule|
        pattern = Regexp.new(rule['search'])
        next unless pattern.match?(parser.body)
        @tags = rule['removal_tags']
      end
      return false
    end

    def clear
      super
      @tag = nil
    end

    def rules
      return handler_config(:rules)
    end
  end
end
