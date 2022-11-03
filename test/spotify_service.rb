module Mulukhiya
  class SpotifyServiceTest < TestCase
    def disable?
      return true unless SpotifyService.config?
      return super
    end

    def setup
      @service = SpotifyService.new
    end

    def test_search_track
      track = @service.search_track('キラキラしちゃってMy True Love！')

      assert_includes(track.name, 'キラキラしちゃって My True Love!')
    end

    def test_lookup_track
      track = @service.lookup_track('1TohZQho6JsNn5SJX44LYD')

      assert_equal('キラキラしちゃって My True Love!', track.name)
    end

    def test_lookup_album
      album = @service.lookup_album('0ownoI5JduviRJOXHTlLwS')

      assert_equal('お願いジュンブライト', album.name)
    end
  end
end
