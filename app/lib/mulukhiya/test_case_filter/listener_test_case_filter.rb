module Mulukhiya
  class ListenerTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.streaming?
      return true unless Environment.daemon_classes.member?(ListenerDaemon)
      return false
    end
  end
end
