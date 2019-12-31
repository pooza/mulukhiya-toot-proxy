module MulukhiyaTootProxy
  class SpotifyTestCaseFilter < TestCaseFilter
    def active?
      return !SpotifyService.config?
    end
  end
end
