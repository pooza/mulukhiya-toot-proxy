module Mulukhiya
  class FilterTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.filter?
      return false
    rescue
      return true
    end
  end
end
