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

      assert_kind_of(Hash, environment_class.health)
      assert_equal('OK', environment_class.health.dig(:redis, :status))
      assert_equal('OK', environment_class.health.dig(:sidekiq, :status))
      assert_equal('OK', environment_class.health.dig(Environment.dbms_class.to_s.split('::').last.underscore.to_sym, :status))
      assert_equal('OK', environment_class.health.dig(:streaming, :status)) if environment_class.daemon_classes.member?(ListenerDaemon)

      assert_equal(200, environment_class.health[:status])
    end
  end
end
