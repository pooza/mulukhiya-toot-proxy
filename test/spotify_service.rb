module MulukhiyaTootProxy
  class SpotifyServiceTest < Test::Unit::TestCase
    def setup
      @service = SpotifyService.new
    end

    def test_search_track
      track = @service.search_track('ガンバランス')
      assert(track.name.include?('ガンバランス'))
    end

    def test_lookup_track
      track = @service.lookup_track('0nfc11o6frUdWKgG51OVFS')
      assert_equal(track.name, 'ツイン・テールの魔法')
    end
  end
end
