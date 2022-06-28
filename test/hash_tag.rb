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
      assert_equal('nowplaying', @nowplaying.name) if @nowplaying
    end

    def test_raw_name
      assert_equal('NowPlaying', @nowplaying.raw_name) if @nowplaying
    end

    def test_uri
      return unless @nowplaying
      assert_kind_of(Ginseng::URI, @nowplaying.uri)
      assert_predicate(@nowplaying.uri, :absolute?)
      assert_match(%r{/nowplaying$}, @nowplaying.uri.path)
    end

    def test_listable?
      assert_boolean(@nowplaying.listable?) if @nowplaying
      assert_boolean(@default.listable?) if @default
    end

    def test_deletable?
      assert_boolean(@nowplaying.deletable?) if @nowplaying
      assert_false(@default.deletable?) if @default
    end

    def test_default?
      assert_boolean(@nowplaying.default?) if @nowplaying
      assert_predicate(@default, :default?) if @default
    end

    def test_remote_default?
      assert_boolean(@nowplaying.remote_default?) if @nowplaying
      assert_boolean(@default.remote_default?) if @default
    end

    def test_local?
      assert_boolean(@nowplaying.local?) if @nowplaying
      assert_boolean(@default.local?) if @default
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
      assert_includes(1..5, feed.count)
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
