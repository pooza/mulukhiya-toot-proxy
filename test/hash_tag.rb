module Mulukhiya
  class HashTagTest < TestCase
    def setup
      @nowplaying = Environment.hash_tag_class.get(tag: 'nowplaying')
      @default = Environment.hash_tag_class.get(tag: TagContainer.default_tag_bases&.first)
      @test_usernames = config['/feed/test_usernames']
    end

    def test_name
      assert_equal(@nowplaying.name, 'nowplaying')
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @nowplaying.uri)
      assert(@nowplaying.uri.path.match?(%r{/nowplaying$}))
    end

    def test_to_h
      assert_kind_of(Hash, @nowplaying.to_h)
    end

    def test_create_feed
      return unless @default
      feed = @default.create_feed(test_usernames: ['test'], limit: 5)
      assert_kind_of(Array, feed)
      assert_equal(feed.count, 5)
      feed.each do |entry|
        assert_kind_of(Hash, entry)
        assert_false(@test_usernames.member?(entry['username']))
      end
    end

    def test_featured_tag_bases
      assert_kind_of(Array, Environment.hash_tag_class.featured_tag_bases)
    end
  end
end
