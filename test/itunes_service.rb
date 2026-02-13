module Mulukhiya
  class ItunesServiceTest < TestCase
    def setup
      @service = ItunesService.new
      stub_request(:get, %r{itunes\.apple\.com/search})
        .to_return(body: fixture('itunes_search_ganbalance.json'))
      stub_request(:get, %r{itunes\.apple\.com/lookup})
        .to_return(body: fixture('itunes_lookup_405905342.json'))
    end

    def test_search
      track = @service.search('ガンバランス', 'music')

      assert_kind_of(Hash, track)
      assert_includes(track['trackName'], 'ガンバランス')
      assert_equal('宮本佳那子', track['artistName'])
    end

    def test_lookup
      track = @service.lookup(405_905_342)

      assert_kind_of(Hash, track)
      assert_equal('宮本佳那子', track['artistName'])
      assert_equal('ガンバランスdeダンス', track['trackName'])
    end
  end
end
