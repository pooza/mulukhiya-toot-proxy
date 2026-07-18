module Mulukhiya
  class HashTagTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return super
    rescue
      return true
    end

    def setup
      return if disable?
      # nowplaying タグ未 seed（harness 等）でも setup をクラッシュさせない。
      # 各テストは `if @nowplaying` / `return unless @nowplaying` で本来 no-op 設計。
      @nowplaying = hash_tag_class.get(tag: 'nowplaying')
      @nowplaying.raw_name = 'NowPlaying' if @nowplaying
      @default = hash_tag_class.get(tag: DefaultTagHandler.tags.first)
    end

    test 'テスト用ハッシュタグの有無' do
      # 実 DB には nowplaying タグが存在するので非 nil を検証する。harness 等未 seed の
      # 環境では構造的に green にできないため precondition 明示 omit（silent skip ではない）。
      # harness 側の seed 追加は chubo2#64。
      omit('テスト用ハッシュタグ未 seed（chubo2#64）') unless @nowplaying

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
      hash_tag_class.favorites.each_value do |values|
        assert_predicate(Ginseng::URI.parse(values[:url]), :absolute?)
        assert_predicate(values[:count], :positive?)
      end
    end

    def test_create_feed
      return unless @default
      feed = @default.create_feed(limit: 5)

      assert_kind_of(Array, feed)
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
