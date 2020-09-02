module Mulukhiya
  class DefaultHashTagTestCaseFilter < TestCaseFilter
    def active?
      return TagContainer.default_tags.empty?
    end
  end
end
