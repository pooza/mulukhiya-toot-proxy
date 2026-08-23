module Mulukhiya
  # ALT 編集の内部 fetch 失敗が、クライアントの 404 に潰れず alert 抑止にも
  # 乗らないこと (#4631)。
  #
  # ⚠⚠ **#4589 の修正で入った 2 本の内部 GET が、素の GatewayError として
  # STATUS_UPDATE_SILENT_STATUSES（401 / 404）の抑止に乗っていた。**
  # 「ALT 編集が全ユーザーで壊れている」が syslog 1 行に消える状態だった。
  class InternalFetchErrorTest < TestCase
    ResponseDouble = Struct.new(:code, :body)

    def setup
      @controller = MastodonController.new!
      @renderer = Ginseng::Web::JSONRenderer.new
      @controller.instance_variable_set(:@renderer, @renderer)
    end

    # ⚠ **クライアントに「その投稿は無い」と読める 404 を返さない。**
    # 実際に無いのではなくモロヘイヤ側の読みが失敗しただけ。
    def test_internal_not_found_is_not_reported_as_client_error
      @controller.handle_gateway_error(
        internal_error(404),
        silent_statuses: MastodonController::STATUS_UPDATE_SILENT_STATUSES,
      )

      assert_equal(502, @renderer.status)
      assert_match(/internal fetch failed/, fetch(@renderer.message, 'error'))
    end

    # ⚠⚠ **これが本命。**404 は抑止対象だが、内部読みの失敗なら alert する。
    def test_internal_error_is_never_silenced
      error = internal_error(404)
      calls = spy(error)

      @controller.handle_gateway_error(
        error,
        silent_statuses: MastodonController::STATUS_UPDATE_SILENT_STATUSES,
      )

      assert_equal([:alert], calls)
    end

    def test_internal_unauthorized_is_never_silenced
      error = internal_error(401)
      calls = spy(error)

      @controller.handle_gateway_error(error)

      assert_equal([:alert], calls)
    end

    # 対照。クライアント起因の 404 は従来どおり静かなまま。
    def test_client_not_found_stays_silent
      error = client_error(404)
      calls = spy(error)

      @controller.handle_gateway_error(
        error,
        silent_statuses: MastodonController::STATUS_UPDATE_SILENT_STATUSES,
      )

      assert_equal([:log], calls)
      assert_equal(404, @renderer.status)
    end

    # 上流のレスポンスは捨てない（e.log に状況を残すため）。
    def test_wrap_keeps_upstream_response
      assert_equal(404, internal_error(404).source_status)
    end

    private

    def spy(error)
      calls = []
      error.define_singleton_method(:alert) {calls << :alert}
      error.define_singleton_method(:log) {calls << :log}
      return calls
    end

    def client_error(status)
      error = Ginseng::GatewayError.new("Bad response #{status}")
      error.response = ResponseDouble.new(status, {error: 'Record not found'}.to_json)
      return error
    end

    def internal_error(status)
      return InternalGatewayError.wrap(client_error(status), :fetch_status)
    end

    def fetch(message, key)
      return message[key] || message[key.to_sym]
    end
  end
end
