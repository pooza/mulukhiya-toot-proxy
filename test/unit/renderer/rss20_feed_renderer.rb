module Mulukhiya
  class RSS20FeedRendererTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return super
    end

    def setup
      return if disable?
      @renderer = RSS20FeedRenderer.new
    end

    def test_parse_entries_array
      entries = @renderer.send(:parse_entries, '[{"title":"a"},{"title":"b"}]')

      assert_kind_of(Array, entries)
      assert_equal(2, entries.size)
    end

    def test_parse_entries_null
      assert_equal([], @renderer.send(:parse_entries, 'null'))
    end

    def test_parse_entries_non_array
      assert_equal([], @renderer.send(:parse_entries, '{"title":"a"}'))
    end

    def test_parse_entries_invalid_json
      assert_equal([], @renderer.send(:parse_entries, 'not json'))
    end

    def test_entries_assignable_from_parsed_null
      # ginseng の entries= は Array 前提なので nil を渡すと each で落ちる。
      # parse_entries 経由なら [] に正規化され安全であることを保証する。
      @renderer.entries = @renderer.send(:parse_entries, 'null')

      assert_empty(@renderer.entries)
    end
  end

  # ⚠ **DBMS が無い環境でも走ること。**RSS20FeedRendererTest は
  # `Environment.dbms_class&.config?` でケースごと omit されるので、そこに置くと
  # この判定が一度も走らない（#4549 で absolute_uri をクラスメソッドにしたのと
  # 同じ理由）。親の initialize は SNS(DB) と Redis を掴むので呼ばない。
  class RSS20FeedRendererRenderTest < TestCase
    class StubRenderer < RSS20FeedRenderer
      attr_reader :logged

      def initialize(values) # rubocop:disable Lint/MissingSuper
        @values = values
        @logged = []
      end

      private

      # レンダー中に絶対化できない値を踏む、を模す。feed.to_s される側なので
      # String を返しておけばよい。
      def feed
        @values.each {|value| unresolved_enclosure(value)}
        return 'rendered'
      end

      def log_unresolved_enclosures
        @logged.push(unresolved_enclosures.dup)
      end
    end

    # レンダーごとに捨てること。捨てないとレンダラがメモ化される経路
    # (CustomFeed#renderer) で伸び続け、count / sample が累積になる (#4560)。
    def test_render_scopes_unresolved_to_one_render
      renderer = StubRenderer.new(['/a.jpg', '/b.jpg'])
      2.times {renderer.send(:render)}

      assert_equal([['/a.jpg', '/b.jpg'], ['/a.jpg', '/b.jpg']], renderer.logged)
      assert_equal(2, renderer.send(:unresolved_enclosures).size)
    end

    def test_render_returns_rendered_body
      assert_equal('rendered', StubRenderer.new([]).send(:render))
    end

    # ⚠ リクエスト経路ではログを出さない。5 分おきの更新側が 1 サイクル 1 行で
    # 出すので十分で、リクエストごとに出すと #4549 の再来になる。
    def test_render_without_log_is_silent
      renderer = StubRenderer.new(['/a.jpg'])
      renderer.send(:render, log: false)

      assert_empty(renderer.logged)
      assert_equal(1, renderer.send(:unresolved_enclosures).size)
    end
  end
end
