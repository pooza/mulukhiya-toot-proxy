module Mulukhiya
  class ItunesURITest < TestCase
    def setup
      @track_url = 'https://music.apple.com/jp/album/%E7%AC%91%E9%A1%94%E3%81%AE%E3%83%A6%E3%83%8B%E3%82%BE%E3%83%B3/1789469284?i=1789469289'
      @album_url = 'https://music.apple.com/jp/album/%E3%82%AD%E3%83%9F%E3%81%A8%E3%82%A2%E3%82%A4%E3%83%89%E3%83%AB%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E3%83%87%E3%83%93%E3%83%A5%E3%83%BC%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB-%E9%80%9A%E5%B8%B8%E7%9B%A4-ep/1789469284'
      @song_url = 'https://music.apple.com/jp/song/%E7%AC%91%E9%A1%94%E3%81%AE%E3%83%A6%E3%83%8B%E3%82%BE%E3%83%B3/1789469289'
    end

    def test_parse
      assert_instance_of(ItunesTrackURI, ItunesURI.create(@track_url))
      assert_instance_of(ItunesAlbumURI, ItunesURI.create(@album_url))
      assert_instance_of(ItunesSongURI, ItunesURI.create(@song_url))
    end
  end
end
