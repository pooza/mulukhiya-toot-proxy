module Mulukhiya
  class DefaultHashTagTestCaseFilter < TestCaseFilter
    def active?
      return DefaultTagHandler.tags.empty? rescue true
    end
  end
end
