module Mulukhiya
  # media_catalog の既定値 (#4789)。
  #
  # ⚠ **Mastodon と Misskey で違う。**Mastodon は 5.41.0 で true に戻した（#4393 の B 案で
  # 追加 index なしに 1 秒未満になったため）。Misskey は #4375 が済むまで false のまま
  # （他者運用のサーバーがあり、アップグレードしただけで有効になる）。
  # ⚠ overlay（local.yaml）に左右されないよう、配布する既定値のファイルを直に読む。
  class MediaCatalogDefaultTest < TestCase
    def test_mastodon_is_enabled_by_default
      assert_true(defaults.dig('mastodon', 'data', 'media_catalog'))
    end

    def test_misskey_stays_disabled_by_default
      assert_false(defaults.dig('misskey', 'data', 'media_catalog'))
    end

    private

    def defaults
      return YAML.load_file(File.join(Environment.dir, 'config/application.yaml'))
    end
  end
end
