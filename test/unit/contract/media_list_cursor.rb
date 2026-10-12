module Mulukhiya
  # `/media` の cursor の形 (5.41.0 のリリース前レビュー)。
  #
  # ⚠ 未認証で届く。Mastodon では数字でない cursor が bigint への変換に失敗して 500 になり、
  # 要求のたびに alert の経路を踏んでいた。
  class MediaListCursorTest < TestCase
    def test_numeric_cursor_is_accepted
      assert_empty(errors(cursor: '115000000000000000'))
    end

    def test_missing_cursor_is_accepted
      assert_empty(errors(page: 2))
    end

    def test_symbols_are_rejected
      assert_not_empty(errors(cursor: "1' OR '1'='1"))
      assert_not_empty(errors(cursor: ''))
    end

    def test_alphabetic_cursor_depends_on_the_server_type
      result = errors(cursor: 'a1b2c3')

      assert_equal(Environment.mastodon_type?, result.present?)
    end

    private

    def errors(params)
      return MediaListContract.new.exec(params)
    end
  end
end
