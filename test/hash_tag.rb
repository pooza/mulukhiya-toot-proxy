module Mulukhiya
  class HashTagTest < TestCase
    def setup
      @nowplaying = hash_tag_class.get(tag: 'nowplaying')
      @nowplaying.raw_name = 'NowPlaying'
      @default = hash_tag_class.get(tag: DefaultTagHandler.tags.first)
    end

    test 'テスト用ハッシュタグの有無' do
      assert_not_nil(@nowplaying)
    end

    def test_name
      return unless @nowplaying
      assert_equal('nowplaying', @nowplaying.name)
    end

    def test_raw_name
      return unless @nowplaying
      assert_equal('NowPlaying', @nowplaying.raw_name)
    end

    def test_uri
      return unless @nowplaying
      assert_kind_of(Ginseng::URI, @nowplaying.uri)
      assert_predicate(@nowplaying.uri, :absolute?)
      assert(@nowplaying.uri.path.match?(%r{/nowplaying$}))
    end

    def test_listable?
      return unless @nowplaying
      assert_boolean(@nowplaying.listable?)
    end

    def test_deletable?
      assert_boolean(@nowplaying.deletable?) if @nowplaying
      assert_false(@default.deletable?) if @default
    end

    def test_default?
      return unless @nowplaying
      assert_boolean(@nowplaying.default?)
    end

    def test_remote_default?
      return unless @nowplaying
      assert_boolean(@nowplaying.remote_default?)
    end

    def test_local?
      return unless @nowplaying
      assert_boolean(@nowplaying.local?)
    end

    def test_to_h
      return unless @nowplaying
      h = @nowplaying.to_h
      assert_kind_of(Hash, h)
      assert_kind_of(String, h[:feed_url])
      assert_boolean(h[:is_default])
      assert_boolean(h[:is_deletable])
      assert_kind_of(String, h[:name])
      assert_kind_of(String, h[:tag])
      assert_kind_of(String, h[:url])
    end

    def test_favorites
      return unless controller_class.favorite_tags?
      assert_kind_of(Hash, hash_tag_class.favorites)
    end

    def test_create_feed
      return unless @default
      feed = @default.create_feed(limit: 5)
      assert_kind_of(Array, feed)
      assert_equal(5, feed.count)
      feed.each do |entry|
        assert_kind_of(Hash, entry)
        assert_predicate(entry[:uri], :present?)
        assert_predicate(entry[:text], :present?)
        assert_predicate(entry[:display_name], :present?)
        assert_predicate(entry[:created_at], :present?)
      end
    end
  end
end
