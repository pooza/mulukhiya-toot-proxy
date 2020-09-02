module Mulukhiya
  class DefaultHashTagTestCaseFilter < TestCaseFilter
    def active?
      return TagContainer.default_tags.empty?
    rescue
      return true
    end
  end
end
