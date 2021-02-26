module Mulukhiya
  class LineTestCaseFilter < TestCaseFilter
    def active?
      return !LineService.config?
    end
  end
end
