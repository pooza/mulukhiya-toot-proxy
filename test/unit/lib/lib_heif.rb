module Mulukhiya
  # HEIF を libheif の版で開け閉めする判定 (#4734)。
  class LibHeifTest < TestCase
    def test_enable_by_version
      assert_false(LibHeif.enable?('1.21.2', loader: true), 'vulcan（Ubuntu）')
      assert_false(LibHeif.enable?('1.22.2', loader: true))
      # 1.23.7 で high 13 件が直った（5.47.1）。1.23.6 は閉じる。
      assert_false(LibHeif.enable?('1.23.4', loader: true))
      assert_false(LibHeif.enable?('1.23.6', loader: true), '2026-11 の FreeBSD の quarterly')
      assert_true(LibHeif.enable?('1.23.7', loader: true))
      assert_true(LibHeif.enable?('1.24.0', loader: true))
    end

    # ⚠ 分からないときは閉じる。
    def test_disable_when_unknown
      assert_false(LibHeif.enable?(nil, loader: true))
      assert_false(LibHeif.enable?('', loader: true))
      assert_false(LibHeif.enable?('1.23.7-rc1', loader: true))
      assert_false(LibHeif.enable?('1.23.7', loader: false), 'libvips に heif のローダが無い')
    end

    # 起動時のログに出す中身（5.47.0 のリリース前レビュー）。答えは `enable?` と同じ。
    def test_summary
      assert_equal({version: '1.23.7', loader: true, enabled: true}, LibHeif.summary(version: '1.23.7', loader: true))
      assert_equal({version: '1.23.6', loader: true, enabled: false}, LibHeif.summary(version: '1.23.6', loader: true))
      assert_equal({version: '1.21.2', loader: true, enabled: false}, LibHeif.summary(version: '1.21.2', loader: true))
      assert_equal({version: nil, loader: false, enabled: false}, LibHeif.summary(version: nil, loader: false))
    end

    # 読み込んでいる libheif の版が取れること（取れないホストでは nil＝閉じる）。
    def test_version
      version = LibHeif.version
      omit('libheif が読めない') unless version

      assert_match(/\A\d+\.\d+\.\d+\z/, version)
    end
  end
end
