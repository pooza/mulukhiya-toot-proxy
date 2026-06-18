module Mulukhiya
  class NowplayingUrlResolverTest < TestCase
    def test_enabled
      assert_true(NowplayingUrlResolver.enabled?)
    end

    # iTunes 経路は資格情報不要で実 API を叩ける (既存 itunes_url_nowplaying_handler
    # テストと同様)。URL → メタの逆引きを確認する。
    def test_resolve_apple_music
      url = 'https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4'
      result = NowplayingUrlResolver.new(url: url).resolve

      assert_equal('apple_music', result[:provider])
      assert_equal('シュビドゥビ☆スイーツタイム', result[:normalized][:title])
      assert_equal('宮本佳那子', result[:normalized][:artist])
      assert_includes(result[:url], 'music.apple.com')
    end

    def test_resolve_returns_nil_url_for_blank
      assert_nil(NowplayingUrlResolver.new(url: '   ').resolve[:url])
    end

    def test_resolve_returns_nil_url_for_unsupported_host
      result = NowplayingUrlResolver.new(url: 'https://www.youtube.com/watch?v=abc').resolve

      assert_nil(result[:url])
    end

    # Spotify 経路は SpotifyService.config? が前提。未設定 (CI 既定) では解決せず
    # {url: nil} を返す (404 にはしない)。
    def test_resolve_spotify_returns_nil_url_without_config
      omit('Spotify configured in this environment') if SpotifyService.config?
      result = NowplayingUrlResolver.new(url: 'https://open.spotify.com/track/2oBorZqiVTpXAD8h7DCYWZ').resolve

      assert_nil(result[:url])
    end
  end
end
