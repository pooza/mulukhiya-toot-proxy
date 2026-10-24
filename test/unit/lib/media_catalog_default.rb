module Mulukhiya
  # media_catalog の既定値 (#4789 / #4838)。
  #
  # Mastodon は 5.41.0、Misskey は 5.43.0 で true に戻した（5.23.0〜は両方 false の実験的扱い）。
  # ⚠ 他者運用のサーバーでは、アップグレードしただけで有効になる。戻すのは overlay の false。
  # ⚠ overlay（local.yaml）に左右されないよう、配布する既定値のファイルを直に読む。
  class MediaCatalogDefaultTest < TestCase
    def test_mastodon_is_enabled_by_default
      assert_true(defaults.dig('mastodon', 'data', 'media_catalog'))
    end

    def test_misskey_is_enabled_by_default
      assert_true(defaults.dig('misskey', 'data', 'media_catalog'))
    end

    private

    def defaults
      return YAML.load_file(File.join(Environment.dir, 'config/application.yaml'))
    end
  end
end
