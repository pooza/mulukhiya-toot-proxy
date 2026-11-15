module Mulukhiya
  # Pleroma 系（Akkoma）の `/media` の cursor（段階 5・#4911）。
  #
  # ⚠ `<投稿の ID（base62 の FlakeId）>.<attachment の中の位置>` の 2 つ組。未認証で届くので、
  # uuid に戻せない ID（128 ビットを超える）は SQL へ渡さない（渡すと 500 になる）。
  class MediaListPleromaCursorTest < TestCase
    def test_composite_cursor_is_accepted
      assert_true(MediaListContract.pleroma_cursor?('BBRwXUDu0uwfOACCsy.1'))
      assert_true(MediaListContract.pleroma_cursor?('BBRwXUDu0uwfOACCsy.12'))
    end

    def test_cursor_without_a_position_is_rejected
      assert_false(MediaListContract.pleroma_cursor?('BBRwXUDu0uwfOACCsy'))
      assert_false(MediaListContract.pleroma_cursor?('BBRwXUDu0uwfOACCsy.'))
      assert_false(MediaListContract.pleroma_cursor?('.1'))
    end

    def test_symbols_are_rejected
      assert_false(MediaListContract.pleroma_cursor?("1' OR '1'='1.1"))
      assert_false(MediaListContract.pleroma_cursor?('BBRwXUDu0uwfOACCsy.1.2'))
      assert_false(MediaListContract.pleroma_cursor?('BBRwXUDu0uwfOACCsy.1234'))
      assert_false(MediaListContract.pleroma_cursor?(''))
    end

    # 🔴 128 ビットを超える ID は uuid に戻せない。⚠ `FlakeId.decode` は 32 桁で切るので、これでは捕まらない。
    def test_overflowing_id_is_rejected
      max = FlakeId.encode('ffffffff-ffff-ffff-ffff-ffffffffffff')

      assert_true(MediaListContract.pleroma_cursor?("#{max}.1"))
      assert_false(MediaListContract.pleroma_cursor?("#{'z' * 22}.1"))
      assert_false(MediaListContract.pleroma_cursor?("#{'1' * 23}.1"))
    end

    # 契約を通した形（Pleroma 系のときだけ）。
    def test_contract
      return unless Environment.pleroma?

      assert_empty(MediaListContract.new.exec(cursor: 'BBRwXUDu0uwfOACCsy.1'))
      assert_not_empty(MediaListContract.new.exec(cursor: '115000000000000000'))
      assert_empty(MediaListContract.new.exec(page: 51, cursor: 'BBRwXUDu0uwfOACCsy.1'))
    end
  end
end
