module Mulukhiya
  class PleromaStatusParser < Ginseng::Fediverse::Parser
    include Package
    attr_accessor :account

    def accts
      return enum_for(__method__) unless block_given?
      text.scan(PleromaStatusParser.acct_pattern).map(&:first).each do |acct|
        yield Acct.new(acct)
      end
    end

    def all_tags
      unless @all_tags
        container = TagContainer.new
        container.concat(tags)
        container.concat(@account.tags) if @account
        return @all_tags = container.create_tags
      end
      return @all_tags
    end

    def max_length
      length = @config['/pleroma/status/max_length']
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end
  end
end
