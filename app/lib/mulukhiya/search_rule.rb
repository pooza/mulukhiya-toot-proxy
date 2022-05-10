module Mulukhiya
  class SearchRule
    include Package
    include SNSMethods
    attr_reader :text

    def initialize(text)
      @text = text.to_s
      parse
    end

    def keywords
      @keywords ||= Set[]
      return @keywords
    end

    def negative_keywords
      @negative_keyrowds ||= Set[]
      return @negative_keyrowds
    end

    private

    def parse
      text.split(/[\s[:blank:]]+/).each do |keyword|
        if keyword.start_with?('-')
          negative_keywords.add(keyword.sub(/^-/, ''))
        else
          keywords.add(keyword)
        end
      end
    end
  end
end
