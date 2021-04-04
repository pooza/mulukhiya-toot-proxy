module Mulukhiya
  class LivecureTestCaseFilter < TestCaseFilter
    def active?
      return !Environment.controller_class.livecure?
    end
  end
end
