module Mulukhiya
  class ListenerTestCaseFilter < TestCaseFilter
    def active?
      return !controller_class.streaming?
    end
  end
end
