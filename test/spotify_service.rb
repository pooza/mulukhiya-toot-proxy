module Mulukhiya
  class SpotifyServiceTest < TestCase
    def setup
      @service = SpotifyService.new
    end

    def test_search_track
      track = @service.search_track('ありがとうのうた')
      assert(track.name.include?('ありがとうのうた'))
    end

    def test_lookup_track
      track = @service.lookup_track('3IOVLLqm6RNpoUVjx33HKF')
      assert_equal(track.name, 'ありがとうのうた')
    end
  end
end
