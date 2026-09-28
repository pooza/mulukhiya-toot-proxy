module Mulukhiya
  # PieFed へのクリップが、モロヘイヤの HTTP を使うこと (#4750)。
  #
  # ⚠ ログインや投稿はしない（利用者の PieFed を要する）。作っただけで見られる `http` の型と、
  # gem の設定（`/piefed/api/version`）が引けたままであることだけを見る。
  class PiefedServiceTest < TestCase
    def setup
      @service = PiefedService.new(url: 'https://piefed.example.com/', user: 'u', password: 'p')
    end

    def test_uses_mulukhiya_http
      assert_kind_of(HTTP, @service.http)
    end

    # ⚠ `include Package` で config_class まで替えると、ここが ConfigError になる。
    def test_keeps_gem_config
      assert_predicate(@service.api_version, :present?)
    end
  end
end
