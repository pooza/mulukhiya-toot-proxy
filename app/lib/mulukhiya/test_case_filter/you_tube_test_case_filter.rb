module Mulukhiya
  class YouTubeTestCaseFilter < TestCaseFilter
    def active?
      return !YouTubeService.config?
    end
  end
end
