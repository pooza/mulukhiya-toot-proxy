module Mulukhiya
  class HashTagTest < TestCase
    def setup
      @nowplaying = hash_tag_class.get(tag: 'nowplaying')
      @nowplaying.raw_name = 'NowPlaying'
      @default = hash_tag_class.get(tag: TagContainer.default_tag_bases&.first)
    end

    def test_name
      assert_equal(@nowplaying.name, 'nowplaying')
    end

    def test_raw_name
      assert_equal(@nowplaying.raw_name, 'NowPlaying')
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @nowplaying.uri)
      assert(@nowplaying.uri.path.match?(%r{/nowplaying$}))
    end

    def test_listable?
      assert_boolean(@nowplaying.listable?)
    end

    def test_to_h
      assert_kind_of(Hash, @nowplaying.to_h)
    end

    def test_favorites
      return unless controller_class.favorite_tags?
      assert_kind_of(Hash, hash_tag_class.favorites)
    end

    def test_create_feed
      return unless @default
      feed = @default.create_feed(limit: 5)
      assert_kind_of(Array, feed)
      assert_equal(feed.count, 5)
      feed.each do |entry|
        assert_kind_of(Hash, entry)
      end
    end
  end
end
