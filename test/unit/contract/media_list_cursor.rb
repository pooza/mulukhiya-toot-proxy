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

    # ⚠ Mastodon の ID は bigint。範囲の外の数字は変換に失敗する（PR #4833 の Codex P2）。
    def test_out_of_range_cursor_is_rejected
      # ⚠ Misskey の ID は英数字なので、長い数字も 64 文字までは形として通る。
      assert_equal(Environment.mastodon_type?, errors(cursor: '9' * 27).present?)
      assert_equal(Environment.mastodon_type?, errors(cursor: (2**63).to_s).present?)
      assert_empty(errors(cursor: ((2**63) - 1).to_s))
      assert_not_empty(errors(cursor: 'a' * 65))
    end

    # ⚠ Misskey の cursor は `<note_id>.<fileIds の中の位置>` の 2 つ組 (#4375)。
    def test_composite_cursor_depends_on_the_server_type
      assert_equal(Environment.mastodon_type?, errors(cursor: 'a1b2c3.2').present?)
      assert_not_empty(errors(cursor: 'a1b2c3.'))
      assert_not_empty(errors(cursor: 'a1b2c3.x'))
      assert_not_empty(errors(cursor: 'a1b2c3.1.2'))
      assert_not_empty(errors(cursor: 'a1b2c3.1234'))
      assert_not_empty(errors(cursor: '.1'))
    end

    def test_alphabetic_cursor_depends_on_the_server_type
      result = errors(cursor: 'a1b2c3')

      assert_equal(Environment.mastodon_type?, result.present?)
    end

    # ⚠⚠ ページの上限（未認証で深いページを引かせない）。
    def test_page_is_capped
      config['/webui/media/catalog/max_page'] = 5

      assert_empty(errors(page: 5))
      assert_not_empty(errors(page: 6))
      assert_not_empty(errors(page: 1_000_000))
    end

    # ⚠ cursor つきの要求では `page` は無視される＝上限にも掛からない（PR #4833 の Codex P2）。
    def test_page_cap_is_ignored_with_a_cursor
      config['/webui/media/catalog/max_page'] = 5
      cursor = Environment.mastodon_type? ? '115000000000000000' : 'a1b2c3'

      assert_empty(errors(page: 51, cursor:))
    end

    private

    def errors(params)
      return MediaListContract.new.exec(params)
    end
  end
end
