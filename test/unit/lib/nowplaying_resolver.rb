module Mulukhiya
  class NowplayingResolverTest < TestCase
    def test_enabled
      assert_true(NowplayingResolver.enabled?)
    end

    def test_resolve_apple_music_hit
      stub_request(:get, %r{itunes\.apple\.com/search})
        .to_return(body: fixture('itunes_search_ganbalance.json'))
      result = NowplayingResolver.new(title: 'ガンバランス', artist: '宮本佳那子').resolve

      assert_equal('apple_music', result[:provider])
      assert_includes(result[:url], 'music.apple.com')
      assert_includes(result[:normalized][:title], 'ガンバランス')
      assert_equal('宮本佳那子', result[:normalized][:artist])
    end

    # ジャケットの URL は `itunes_image` の `pixel`（既定 480）に揃える (#4769)。
    def test_resolve_apple_music_artwork_url
      stub_request(:get, %r{itunes\.apple\.com/search})
        .to_return(body: fixture('itunes_search_ganbalance.json'))
      result = NowplayingResolver.new(title: 'ガンバランス', artist: '宮本佳那子').resolve

      assert_match(%r{\Ahttps://.+/480x480bb\.jpg\z}, result[:artwork_url])
    end

    # ⚠ キーは常に返す（取れなければ null・#4769）。
    def test_resolve_returns_nil_url_when_no_hit
      stub_request(:get, %r{itunes\.apple\.com/search})
        .to_return(body: {resultCount: 0, results: []}.to_json)
      result = NowplayingResolver.new(title: 'no such song xyzzy').resolve

      assert_nil(result[:url])
      assert(result.key?(:artwork_url))
      assert_nil(result[:artwork_url])
    end

    def test_resolve_returns_nil_url_for_blank_title
      result = NowplayingResolver.new(title: '   ').resolve

      assert_nil(result[:url])
      assert(result.key?(:artwork_url))
    end

    def test_apple_music_artwork_url_without_artwork
      assert_nil(NowplayingResolver.apple_music_artwork_url(nil, 480))
    end

    # Spotify は任意サイズを作れないので、`pixel` 以上で最小のものを選ぶ。
    def test_spotify_artwork_url_picks_smallest_sufficient
      images = [
        {'url' => 'https://i.scdn.co/640', 'width' => 640, 'height' => 640},
        {'url' => 'https://i.scdn.co/300', 'width' => 300, 'height' => 300},
        {'url' => 'https://i.scdn.co/64', 'width' => 64, 'height' => 64},
      ]

      assert_equal('https://i.scdn.co/640', NowplayingResolver.spotify_artwork_url(images, 480))
      assert_equal('https://i.scdn.co/300', NowplayingResolver.spotify_artwork_url(images, 300))
    end

    # 足りるものが無ければ最大のもの。
    def test_spotify_artwork_url_falls_back_to_largest
      images = [{'url' => 'https://i.scdn.co/300', 'width' => 300}, {'url' => 'https://i.scdn.co/64', 'width' => 64}]

      assert_equal('https://i.scdn.co/300', NowplayingResolver.spotify_artwork_url(images, 480))
    end

    def test_spotify_artwork_url_with_unknown_width
      images = [
        {'url' => 'https://i.scdn.co/unknown', 'width' => nil},
        {'url' => 'https://i.scdn.co/300', 'width' => 300},
        {'url' => 'https://i.scdn.co/64', 'width' => 64},
      ]

      assert_equal('https://i.scdn.co/unknown', NowplayingResolver.spotify_artwork_url(images, 480))
      assert_equal('https://i.scdn.co/300', NowplayingResolver.spotify_artwork_url(images, 300))
      assert_equal('https://i.scdn.co/only', NowplayingResolver.spotify_artwork_url([{'url' => 'https://i.scdn.co/only'}], 480))
    end

    def test_spotify_artwork_url_without_images
      assert_nil(NowplayingResolver.spotify_artwork_url([], 480))
      assert_nil(NowplayingResolver.spotify_artwork_url(nil, 480))
    end

    def test_provider_order_prefers_explicit_prefer
      resolver = NowplayingResolver.new(
        title: 'x', source_app_name: 'Apple Music', prefer: 'spotify',
      )

      assert_equal(['spotify', 'apple_music'], resolver.send(:provider_order))
    end

    def test_provider_order_uses_source_app_hint
      resolver = NowplayingResolver.new(title: 'x', source_app_name: 'Spotify')

      assert_equal(['spotify', 'apple_music'], resolver.send(:provider_order))
    end

    def test_provider_order_defaults_to_apple_music
      resolver = NowplayingResolver.new(title: 'x', source_app_name: 'VLC')

      assert_equal(['apple_music', 'spotify'], resolver.send(:provider_order))
    end

    def test_provider_order_ignores_invalid_prefer
      resolver = NowplayingResolver.new(title: 'x', prefer: 'youtube')

      assert_equal(['apple_music', 'spotify'], resolver.send(:provider_order))
    end

    def test_keyword_includes_all_metadata
      resolver = NowplayingResolver.new(title: 'song', artist: 'a', album: 'b')

      assert_equal('song a b', resolver.send(:keyword))
    end

    def test_keyword_skips_blank_fields
      resolver = NowplayingResolver.new(title: 'song', album: 'b')

      assert_equal('song b', resolver.send(:keyword))
    end
  end
end
