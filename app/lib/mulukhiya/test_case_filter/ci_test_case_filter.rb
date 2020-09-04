module Mulukhiya
  class CITestCaseFilter < TestCaseFilter
    def active?
      return Environment.ci?
    end
  end
end
