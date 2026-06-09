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

    def test_resolve_returns_nil_url_when_no_hit
      stub_request(:get, %r{itunes\.apple\.com/search})
        .to_return(body: {resultCount: 0, results: []}.to_json)
      result = NowplayingResolver.new(title: 'no such song xyzzy').resolve

      assert_nil(result[:url])
    end

    def test_resolve_returns_nil_url_for_blank_title
      result = NowplayingResolver.new(title: '   ').resolve

      assert_nil(result[:url])
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
  end
end
