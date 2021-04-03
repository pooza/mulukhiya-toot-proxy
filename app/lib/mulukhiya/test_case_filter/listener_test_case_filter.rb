module Mulukhiya
  class ListenerTestCaseFilter < TestCaseFilter
    def active?
      return !Environment.controller_class.streaming?
    end
  end
end
