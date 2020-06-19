module Mulukhiya
  class PleromaTestCaseFilter < TestCaseFilter
    def active?
      return Environment.pleroma?
    end
  end
end
