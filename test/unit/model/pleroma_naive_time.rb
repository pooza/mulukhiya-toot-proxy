module Mulukhiya
  # Akkoma のタイムゾーンの無い列を UTC として読み直す (#4864)。⚠ `expired?` のほかは DB に繋がない。
  # ⚠ 手元（JST）と CI（UTC）で結果が変わらないよう、オフセットを明示した時刻で組む。
  class PleromaNaiveTimeTest < TestCase
    # DB の `2126-09-21 22:19:28.004801`（UTC）を、Sequel が JST として読んだ形。
    def naive_jst
      return Time.new(2126, 9, 21, 22, 19, 28.004801r, '+09:00')
    end

    def test_utc
      assert_equal(Time.utc(2126, 9, 21, 22, 19, 28.004801r), Pleroma::NaiveTime.utc(naive_jst))
      assert_predicate(Pleroma::NaiveTime.utc(naive_jst), :utc?)
    end

    # 既に UTC で返った値は変えない。
    def test_utc_idempotent
      value = Time.utc(2126, 9, 21, 22, 19, 28.004801r)

      assert_equal(value, Pleroma::NaiveTime.utc(value))
    end

    def test_utc_nil
      assert_nil(Pleroma::NaiveTime.utc(nil))
    end

    # 期限が「UTC では未来・JST として読むと過去」になる値で、期限切れと判定しない。
    def test_expired
      omit('Akkoma の DB が要る') unless Environment.pleroma?
      token = Pleroma::AccessToken.new
      now = Time.utc(2026, 11, 5, 3, 0, 0)
      # DB の `2026-11-05 06:00:00`（UTC）＝ 3 時間後。JST として読むと前日の 21:00 UTC ＝ 過去になる。
      token.values[:valid_until] = Time.new(2026, 11, 5, 6, 0, 0, '+09:00')

      assert_false(token.expired?(now))
      # DB の `2026-11-05 02:00:00`（UTC）＝ 1 時間前。
      token.values[:valid_until] = Time.new(2026, 11, 5, 2, 0, 0, '+09:00')

      assert_true(token.expired?(now))
      token.values[:valid_until] = nil

      assert_false(token.expired?(now))
    end
  end
end
