module Mulukhiya
  class PleromaStatusParser < TootParser
    include Package
    attr_accessor :account

    def max_length
      length = @config['/pleroma/status/max_length']
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end
  end
end
