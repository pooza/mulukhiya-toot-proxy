require 'rack/test'

module Mulukhiya
  # `POST /webhook/admin` の失敗は黙らせないが、連打はデッドマンで抑える (#4723)。
  #
  # ⚠ **署名不一致（`AuthError`）は 4xx でも鳴らす (#4603)。**ただし従来の `e.alert` は
  # 不一致のたびに Sentry ＋ Event(:alert)（slack / line / mail）を飛ばしていたので、
  # 外から叩かれ続けると通知が埋まる。`report_error` のデッドマンと同じ
  # `throttled_alert` に寄せる。
  class WebhookAdminAlertTest < TestCase
    include Rack::Test::Methods

    # 署名検証までを差し替えて、`rescue` だけを見る。ルートは継承される。
    class AdminProbeController < WebhookController
      set :raise_errors, false
      set :show_exceptions, false

      class << self
        attr_accessor :probe
      end

      def info_agent_service
        return Object.new
      end

      def verify_admin_webhook!(_raw_body)
        raise self.class.probe
      end
    end

    def app = AdminProbeController

    def setup
      clear_alert_throttle(Ginseng::AuthError)
    end

    def teardown
      clear_alert_throttle(Ginseng::AuthError)
    end

    # 🔴 1 回目は鳴らす（黙らせない）。
    def test_first_signature_mismatch_is_alerted
      error = probe(Ginseng::AuthError.new('Invalid signature'))

      assert_equal([:alert], error.mulukhiya_calls)
      assert_equal(403, last_response.status)
    end

    # 🔴 連打は窓のあいだ log 止め。
    def test_repeated_signature_mismatch_is_throttled
      probe(Ginseng::AuthError.new('Invalid signature'))
      error = probe(Ginseng::AuthError.new('Invalid signature'))

      assert_equal([:log], error.mulukhiya_calls)
      assert_equal(403, last_response.status)
    end

    private

    # ⚠ Sinatra のホスト認可で 403 になるので Host を明示する。
    # ⚠ **Rack 3 では `rack.input` が任意**で、rack-test は省略する。明示して埋める。
    def probe(error)
      AdminProbeController.probe = spy(error)
      post('/admin', {}, 'HTTP_HOST' => 'localhost', 'rack.input' => StringIO.new('{}'))
      return AdminProbeController.probe
    end

    def spy(error)
      calls = []
      error.define_singleton_method(:mulukhiya_calls) {calls}
      error.define_singleton_method(:alert) {|*| calls << :alert}
      error.define_singleton_method(:log) {|*| calls << :log}
      return error
    end
  end
end
