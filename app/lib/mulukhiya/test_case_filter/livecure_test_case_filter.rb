module Mulukhiya
  class LivecureTestCaseFilter < TestCaseFilter
    def active?
      return !controller_class.livecure?
    end
  end
end
