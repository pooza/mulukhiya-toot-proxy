module Mulukhiya
  class SpotifyServiceTest < TestCase
    def setup
      @service = SpotifyService.new
    end

    def test_search_track
      track = @service.search_track('キラキラしちゃってMy True Love！')
      assert(track.name.include?('キラキラしちゃって My True Love!'))
    end

    def test_lookup_track
      track = @service.lookup_track('1TohZQho6JsNn5SJX44LYD')
      assert_equal(track.name, 'キラキラしちゃって My True Love!')
    end

    def test_lookup_album
      album = @service.lookup_album('0ownoI5JduviRJOXHTlLwS')
      assert_equal(album.name, 'お願いジュンブライト')
    end
  end
end
