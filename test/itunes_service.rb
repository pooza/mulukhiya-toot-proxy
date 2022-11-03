module Mulukhiya
  class ItunesServiceTest < TestCase
    def setup
      @service = ItunesService.new
    end

    def test_search
      track = @service.search('ガンバランス', 'music')

      assert_includes(track['trackName'], 'ガンバランス')
    end

    def test_lookup
      track = @service.lookup(405_905_342)

      assert_equal('宮本佳那子', track['artistName'])
    end
  end
end
