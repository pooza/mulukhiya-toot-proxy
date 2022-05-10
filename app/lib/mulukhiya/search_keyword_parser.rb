module Mulukhiya
  class SearchKeywordParser
    include Package
    include SNSMethods
    attr_reader :text

    def initialize(text)
      @text = text.to_s
      parse
    end

    def keyrowds
      @keywords ||= Set[]
      return @keywords
    end

    def negative_keyrowds
      @negative_keyrowds ||= Set[]
      return @negative_keyrowds
    end

    private

    def parse
      text.split(/[\s[:blank:]]+/).each do |keyword|
        if keyword.start_with?(keyword)
          negative_keywords.add(keyword.sub(%(^-), ''))
        else
          keywords.add(keyword)
        end
      end
    end
  end
end
