module Mulukhiya
  class SlackTestCaseFilter < TestCaseFilter
    def active?
      return !SlackService.config?
    end
  end
end
