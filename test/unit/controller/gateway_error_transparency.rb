module Mulukhiya
  # 上流のエラー包絡がクライアントまで届くこと (#4480)。
  #
  # モロヘイヤはプロキシなので、上流が返した理由（Misskey の TOO_MANY_DRAFTS、
  # Mastodon の Validation failed）を素通しするのが本来の姿。従来は
  # Ginseng::HTTP が上流ボディを捨てて "Bad response NNN" に潰していた。
  class GatewayErrorTransparencyTest < TestCase
    # 上流レスポンスのダブル。GatewayError#source_body / #source_status が
    # 見るのは code と body だけ。
    ResponseDouble = Struct.new(:code, :body)

    def setup
      @controller = MisskeyController.new!
      @renderer = Ginseng::Web::JSONRenderer.new
      @controller.instance_variable_set(:@renderer, @renderer)
    end

    # 正のケース: 上流の code がクライアントまで届く。
    def test_passes_upstream_json_through
      error = build_error(400, {error: {code: 'TOO_MANY_DRAFTS', id: 'deadbeef'}}.to_json)

      @controller.handle_gateway_error(error)

      assert_equal('TOO_MANY_DRAFTS', @renderer.message.dig(:error, :code) || @renderer.message.dig('error', 'code'))
      assert_equal(400, @renderer.status)
    end

    def test_passes_mastodon_flat_error_through
      error = build_error(422, {error: 'Validation failed: Text is too long'}.to_json)

      @controller.handle_gateway_error(error)

      assert_equal('Validation failed: Text is too long', fetch(@renderer.message, 'error'))
      assert_equal(422, @renderer.status)
    end

    # ⚠ 上流が HTML を返すことがある（nginx の 502 等）。素通しするとプロキシが
    # 他人の HTML を吐くので、従来どおり {error: e.message} に倒れる。
    def test_falls_back_to_message_for_html_body
      error = build_error(502, '<html><body>Bad Gateway</body></html>')

      @controller.handle_gateway_error(error)

      assert_equal('Bad response 502', fetch(@renderer.message, 'error'))
      assert_equal(502, @renderer.status)
    end

    def test_falls_back_to_message_without_response
      error = Ginseng::GatewayError.new('Bad response 404')

      @controller.handle_gateway_error(error)

      assert_equal('Bad response 404', fetch(@renderer.message, 'error'))
      assert_equal(404, @renderer.status)
    end

    # 上流ボディに内部情報を混ぜない。message は上流ボディが読めたときには使わない。
    def test_does_not_mix_internal_message_into_upstream_body
      error = build_error(400, {error: {code: 'NO_SUCH_NOTE'}}.to_json)

      @controller.handle_gateway_error(error)

      assert_not_includes(@renderer.message.to_s, 'Bad response')
    end

    # ⚠ 配列は透過しない (#4537)。`source_body` は JSON の配列も返しうるが、
    # クライアントは `{"error": ...}` を期待しているので読めない。
    def test_falls_back_to_message_for_array_body
      error = build_error(400, [{code: 'NO_SUCH_NOTE'}].to_json)

      @controller.handle_gateway_error(error)

      assert_equal('Bad response 400', fetch(@renderer.message, 'error'))
      assert_equal(400, @renderer.status)
    end

    # ⚠ 透過してよいのは**自分の上流**が返したものだけ (#4537)。引用元の他人の
    # サーバー由来はステータスもボディも返さない。
    def test_does_not_pass_foreign_gateway_error_through
      error = ForeignGatewayError.new('Bad response 451')
      error.response = ResponseDouble.new(451, {error: 'Unavailable For Legal Reasons'}.to_json)

      @controller.handle_gateway_error(error)

      assert_equal('Bad response 451', fetch(@renderer.message, 'error'))
      assert_equal(502, @renderer.status, '他人のサーバーのステータスを返さない')
    end

    # 印を付け替えても上流のレスポンスは保つ（ログに残すため）。
    def test_foreign_gateway_error_keeps_upstream_response
      source = build_error(451, {error: 'Unavailable For Legal Reasons'}.to_json)
      wrapped = ForeignGatewayError.wrap(source)

      assert_equal(451, wrapped.source_status)
      assert_equal('Unavailable For Legal Reasons', wrapped.source_body['error'])
      assert_equal(source.message, wrapped.message)
    end

    # Sentry alert の抑止条件。ステータスとコードの両方で効くこと。
    def test_alert_is_suppressed_by_status
      error = build_error(401, '{}')

      assert_false(alerted?(error) {@controller.handle_gateway_error(error)})
    end

    def test_alert_is_suppressed_by_code
      error = build_error(400, {error: {code: 'TOO_MANY_DRAFTS'}}.to_json)

      assert_false(
        alerted?(error) do
          @controller.handle_gateway_error(error, silent_codes: MisskeyController::USER_FAULT_CODES)
        end,
      )
    end

    # ⚠ 抑止リストに無い失敗は必ず alert する（黙らせすぎない）。
    def test_alert_fires_for_unknown_failure
      error = build_error(500, {error: {code: 'INTERNAL_ERROR'}}.to_json)

      assert_true(
        alerted?(error) do
          @controller.handle_gateway_error(error, silent_codes: MisskeyController::USER_FAULT_CODES)
        end,
      )
    end

    # ALT 編集 (PUT /api/:version/statuses/:id) の 404 はクライアント起因なので
    # alert しない (#4542)。抑止側は「実際に抑止していること」を正で押さえる。
    def test_alert_is_suppressed_for_status_update_not_found
      error = build_error(404, {error: 'Record not found'}.to_json)

      assert_false(
        alerted?(error) do
          @controller.handle_gateway_error(
            error,
            silent_statuses: MastodonController::STATUS_UPDATE_SILENT_STATUSES,
          )
        end,
      )
    end

    # ⚠ 黙らせるのは 401 / 404 だけ。上流の 5xx まで抑止すると、
    # 「/source が廃止されて ALT 編集が全滅」を Sentry で拾えなくなる。
    def test_alert_fires_for_status_update_server_error
      error = build_error(500, {error: 'Internal Server Error'}.to_json)

      assert_true(
        alerted?(error) do
          @controller.handle_gateway_error(
            error,
            silent_statuses: MastodonController::STATUS_UPDATE_SILENT_STATUSES,
          )
        end,
      )
    end

    def test_user_fault_codes_covers_known_misskey_codes
      ['TOO_MANY_DRAFTS', 'ALREADY_FAVORITED', 'NO_SUCH_NOTE', 'MAX_FILE_SIZE_EXCEEDED'].each do |code|
        assert_includes(MisskeyController::USER_FAULT_CODES, code)
      end
    end

    private

    def build_error(code, body)
      error = Ginseng::GatewayError.new("Bad response #{code}")
      error.response = ResponseDouble.new(code, body)
      return error
    end

    def fetch(message, key)
      return message[key.to_sym] || message[key]
    end

    # alert が呼ばれたかどうか。Sentry へ実際に送らないよう差し替える。
    def alerted?(error)
      called = false
      error.define_singleton_method(:alert) {|**_opts| called = true}
      yield
      return called
    end
  end
end
