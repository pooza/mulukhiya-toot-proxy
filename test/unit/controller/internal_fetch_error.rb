module Mulukhiya
  # ALT 編集の内部 fetch 失敗が、クライアントの 404 に潰れず alert 抑止にも
  # 乗らないこと (#4631)。
  #
  # ⚠⚠ **#4589 の修正で入った 2 本の内部 GET が、素の GatewayError として
  # STATUS_UPDATE_SILENT_STATUSES（401 / 404）の抑止に乗っていた。**
  # 「ALT 編集が全ユーザーで壊れている」が syslog 1 行に消える状態だった。
  class InternalFetchErrorTest < TestCase
    ResponseDouble = Struct.new(:code, :body)
    SOURCE = {'text' => '本文', 'spoiler_text' => ''}.freeze
    STATUS = {'sensitive' => false, 'media_attachments' => [], 'poll' => nil}.freeze

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

    # ⚠⚠ **ここからが Codex P1 の懸念（#4647）。**「投稿が消えている」
    # 「リモートの投稿」「トークンが切れている」は**本当にクライアント起因の 4xx** で、
    # 日常的に通る。一律に内部エラー扱いすると、古い投稿を編集しようとしただけで
    # 502 と Sentry イベントが出る。

    # 1 本目が 404 = 投稿が無い。両方落ちるので非対称にならない。
    def test_first_fetch_client_error_is_preserved
      controller = controller_with(source: client_error(404))
      error = assert_raise(Ginseng::GatewayError) {restore(controller)}

      assert_not_kind_of(InternalGatewayError, error)
    end

    # トークン切れも同じ。
    def test_first_fetch_unauthorized_is_preserved
      controller = controller_with(source: client_error(401))
      error = assert_raise(Ginseng::GatewayError) {restore(controller)}

      assert_not_kind_of(InternalGatewayError, error)
    end

    # ⚠⚠ **これが #4621 の症状。**1 本目が通ったのに 2 本目だけ落ちるのは、
    # クライアント起因ではありえない（投稿が無いなら両方 404 になる）。
    def test_asymmetric_failure_is_internal
      controller = controller_with(status: client_error(404))

      assert_raise(InternalGatewayError) {restore(controller)}
    end

    # 5xx はクライアントの操作では作れない。
    def test_server_error_is_internal
      controller = controller_with(source: client_error(502))

      assert_raise(InternalGatewayError) {restore(controller)}
    end

    private

    # fetch_status_source / fetch_status のダブル。指定された側だけ raise する。
    class SnsDouble
      def initialize(source:, status:)
        @source = source
        @status = status
      end

      def fetch_status_source(_id, _opts) = resolve(@source)
      def fetch_status(_id, _opts) = resolve(@status)

      private

      def resolve(value)
        raise value if value.is_a?(StandardError)
        return value
      end
    end

    def controller_with(source: SOURCE, status: STATUS)
      controller = MastodonController.new!
      controller.instance_variable_set(:@sns, SnsDouble.new(source:, status:))
      controller.instance_variable_set(:@headers, {})
      return controller
    end

    def restore(controller)
      return controller.send(:restored_body, '1')
    end

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
