module Mulukhiya
  class SpotifyTestCaseFilter < TestCaseFilter
    def active?
      return !SpotifyService.config?
    end
  end
end
