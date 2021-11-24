module Mulukhiya
  class TaggingHandlerTest < TestCase
    def setup
      @handler = Handler.create('tagging')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({})
      assert_equal(@handler.payload[status_field], '')

      @handler.clear
      @handler.handle_pre_toot(status_field => nil)
      assert_equal(@handler.payload[status_field], '')

      @handler.clear
      @handler.handle_pre_toot(status_field => "本文\n本文\n#1行目\n#2行目")
      assert_equal(@handler.payload[status_field], "本文\n本文\n#2行目 #1行目")

      @handler.clear
      @handler.handle_pre_toot(status_field => "本文\n本文\n#1行目\n#2行目\nhttps://google.co.jp")
      assert_equal(@handler.payload[status_field], "本文\n本文\n#2行目 #1行目\nhttps://google.co.jp")

      @handler.clear
      @handler.tags.merge(['宮本佳那子', 'precure_fun', 'music_apple_com', 'iTunes'])
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com/jp/album/1439287709?i=1439287882\nTitle: Kanako's プリキュア・エンディングテーマ・メドレー\nAlbum: PRECURE Best Songs Selection 「Dear my past self」\nArtist: 宮本佳那子")
      assert_equal(@handler.payload[status_field], "#nowplaying https://music.apple.com/jp/album/1439287709?i=1439287882\nTitle: Kanako's プリキュア・エンディングテーマ・メドレー\nAlbum: PRECURE Best Songs Selection 「Dear my past self」\nArtist: 宮本佳那子\n#宮本佳那子 #precure_fun #music_apple_com #iTunes")
    end
  end
end
