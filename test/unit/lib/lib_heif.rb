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
    # 使った基準の版も出す (#4924)。
    def test_summary
      safe = LibHeif::SAFE_VERSION

      assert_equal({version: '1.23.7', loader: true, safe_version: safe, enabled: true},
        LibHeif.summary(version: '1.23.7', loader: true, safe_version: safe))
      assert_equal({version: '1.23.6', loader: true, safe_version: safe, enabled: false},
        LibHeif.summary(version: '1.23.6', loader: true, safe_version: safe))
      assert_equal({version: '1.21.2', loader: true, safe_version: safe, enabled: false},
        LibHeif.summary(version: '1.21.2', loader: true, safe_version: safe))
      assert_equal({version: nil, loader: false, safe_version: safe, enabled: false},
        LibHeif.summary(version: nil, loader: false, safe_version: safe))
      assert_equal({version: '1.23.7', loader: true, safe_version: '1.23.8', enabled: false},
        LibHeif.summary(version: '1.23.7', loader: true, safe_version: '1.23.8'))
    end

    # 設定は上げる方向にだけ効く (#4924)。
    def test_safe_version
      assert_equal(LibHeif::SAFE_VERSION, LibHeif.safe_version(nil), '設定なし')
      assert_equal('1.23.8', LibHeif.safe_version('1.23.8'), '上げる')
      assert_equal('1.24', LibHeif.safe_version('1.24'))
      assert_equal(LibHeif::SAFE_VERSION, LibHeif.safe_version('1.23.4'), '下げられない')
      assert_equal(LibHeif::SAFE_VERSION, LibHeif.safe_version(LibHeif::SAFE_VERSION))
      assert_equal(LibHeif::SAFE_VERSION, LibHeif.safe_version('1.23.8-rc1'), '版として読めない')
      assert_equal(LibHeif::SAFE_VERSION, LibHeif.safe_version(''))
    end

    def test_enable_by_configured_version
      assert_false(LibHeif.enable?('1.23.7', loader: true, safe_version: '1.23.8'))
      assert_true(LibHeif.enable?('1.23.8', loader: true, safe_version: '1.23.8'))
    end

    # 設定から読む（無ければ nil）。
    # ⚠ 設定は自分で戻す。残すと、後のテストの `enable?` が既定の基準で答えなくなる。
    def test_configured_safe_version
      original = LibHeif.configured_safe_version
      config['/media/heif/safe_version'] = '1.99.0'

      assert_equal('1.99.0', LibHeif.configured_safe_version)
      assert_equal('1.99.0', LibHeif.safe_version)
    ensure
      config['/media/heif/safe_version'] = original
    end

    # 読み込んでいる libheif の版が取れること（取れないホストでは nil＝閉じる）。
    def test_version
      version = LibHeif.version
      omit('libheif が読めない') unless version

      assert_match(/\A\d+\.\d+\.\d+\z/, version)
    end
  end
end
