module Mulukhiya
  class TaggingHandlerTest < TestCase
    def setup
      @handler = Handler.create(:tagging)
      config['/handler/tagging/normalize/rules'].push(
        'source' => 'ふたりはプリキュア_Max_Heart',
        'normalized' => 'ふたりはプリキュアMax_Heart',
      )
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({})

      assert_equal('', @handler.payload[status_field])

      @handler.clear
      @handler.handle_pre_toot(status_field => nil)

      assert_equal('', @handler.payload[status_field])

      @handler.clear
      @handler.handle_pre_toot(status_field => "本文\n本文\n#1行目\n#2行目")

      assert_equal("本文\n本文\n\n#2行目 #1行目", @handler.payload[status_field])

      @handler.clear
      @handler.handle_pre_toot(status_field => "本文\n本文\n#ふたりはプリキュア_Max_Heart")

      assert_equal("本文\n本文\n\n#ふたりはプリキュアMax_Heart", @handler.payload[status_field])

      @handler.clear
      @handler.tags.merge(['宮本佳那子', 'precure_fun', 'music_apple_com', 'iTunes'])
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com/jp/album/1439287709?i=1439287882\nTitle: Kanako's プリキュア・エンディングテーマ・メドレー\nAlbum: PRECURE Best Songs Selection 「Dear my past self」\nArtist: 宮本佳那子")

      assert_equal("#nowplaying https://music.apple.com/jp/album/1439287709?i=1439287882\nTitle: Kanako's プリキュア・エンディングテーマ・メドレー\nAlbum: PRECURE Best Songs Selection 「Dear my past self」\nArtist: 宮本佳那子\n\n#宮本佳那子 #precure_fun #music_apple_com #iTunes", @handler.payload[status_field])

      @handler.clear
      @handler.handle_pre_toot(status_field => ':nyatoran_anime: :pegitan_anime: :rabirin_anime:')

      assert_equal(":nyatoran_anime: :pegitan_anime: :rabirin_anime:\n\n", @handler.payload[status_field])
    end
  end
end
