module Mulukhiya
  class EnvironmentTest < TestCase
    def test_daemon_classes
      assert_kind_of(Set, environment_class.daemon_classes)
    end

    def test_task_prefixes
      assert_kind_of(Set, environment_class.task_prefixes)
    end

    def test_health
      return unless Environment.dbms_class&.config?

      health = environment_class.health
      dbms_key = Environment.dbms_class.to_s.split('::').last.underscore.to_sym
      # redis / DBMS は harness が提供する（DB・redis 直結）ので常に検証する。
      assert_kind_of(Hash, health)
      assert_equal('OK', health.dig(:redis, :status))
      assert_equal('OK', health.dig(dbms_key, :status))

      # sidekiq / streaming / 総合ステータス 200 は mulukhiya デーモン層の常駐を前提とする。
      # harness は proxy=nginx・web/sidekiq=Mastodon 自身のみで mulukhiya のデーモンを持たず、
      # sidekiq は構造的に NG になる。harness 駆動時のみ明示 omit する（silent skip ではない）。
      # 非 harness（本番/フルスタックのスモーク）で sidekiq NG なら実退行として下の assert で
      # 落とす。harness 側の provisioning は chubo2#63。
      omit('mulukhiya sidekiq 未常駐（harness はデーモン層を提供しない・chubo2#63）') \
        if harness? && SidekiqDaemon.health[:status] != 'OK'

      assert_equal('OK', health.dig(:sidekiq, :status))
      assert_equal('OK', health.dig(:streaming, :status)) if environment_class.daemon_classes.member?(ListenerDaemon)

      assert_equal(200, health[:status])
    end
  end
end
