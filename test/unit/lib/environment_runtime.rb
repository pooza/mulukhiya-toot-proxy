module Mulukhiya
  # ランタイムの能力欠落を health で検知する (#4466)。
  #
  # ガードが「実際に NG を返す」ことを正のテストで押さえる。config を
  # rescue で握り潰す実装だとアサーションが黙って無効化されるため
  # (MEMORY feedback_fail-open-guard-footgun)。
  class EnvironmentRuntimeTest < TestCase
    def teardown
      super
      config.reload
    end

    def test_ruby_health_shape
      health = Environment.ruby_health

      assert_equal(RUBY_VERSION, health[:version])
      assert_boolean(health[:yjit_available])
      assert_boolean(health[:yjit_enabled])
      assert_include(['OK', 'NG'], health[:status])
    end

    # 既定は情報として出すだけ。能力の欠落で health を 503 にはしない。
    def test_ruby_status_is_informational_by_default
      config['/runtime/require_yjit'] = false

      assert_equal('OK', Environment.ruby_status(false))
      assert_equal('OK', Environment.ruby_status(true))
      assert_false(Environment.require_yjit?)
    end

    # opt-in したサーバーでは実際に NG になる。
    def test_ruby_status_is_ng_when_yjit_required_but_missing
      config['/runtime/require_yjit'] = true

      assert_true(Environment.require_yjit?)
      assert_equal('NG', Environment.ruby_status(false))
      assert_equal('OK', Environment.ruby_status(true))
    end
  end
end
