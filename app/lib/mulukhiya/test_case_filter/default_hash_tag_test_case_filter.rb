module Mulukhiya
  class DefaultHashTagTestCaseFilter < TestCaseFilter
    def active?
      return TagContainer.default_tags.empty? rescue true
    end
  end
end
