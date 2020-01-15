module Mulukhiya
  class ItunesServiceTest < TestCase
    def setup
      @service = ItunesService.new
    end

    def test_search
      track = @service.search('ガンバランス', 'music')
      assert(track['trackName'].include?('ガンバランス'))
    end

    def test_lookup
      track = @service.lookup(405_905_342)
      assert_equal(track['artistName'], '宮本佳那子')
    end
  end
end
