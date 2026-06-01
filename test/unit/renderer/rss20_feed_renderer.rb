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
end
