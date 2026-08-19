module Mulukhiya
  # gem 境界のテスト (#4594)。
  #
  # `MastodonService#upload` が上流の失敗をどの例外クラスで返してくるかは、
  # モロヘイヤのアラート抑止が効くかどうかを直接左右する。かつて
  # ginseng-fediverse は `GatewayError` を `ValidateError` に詰め替えており、
  # `mastodon_controller.rb` の `rescue Ginseng::GatewayError` を素通りしていた
  # (pooza/ginseng-fediverse#246)。その結果 401 の抑止も 413 の文言も一度も
  # 到達せず、ボットの無効トークン連打が管理者へのアラートメールになった。
  #
  # ⚠ `gateway_error_transparency` の `handle_upload_gateway_error` 側テストは
  # gem を通らないので、この退行を捕まえられない。**gem が何を投げてくるか**を
  # 押さえるのはこのファイルの役目。bundle update で黙って壊れる類なので、
  # 上流の実装ではなく境界の契約として残す。
  class MastodonUploadErrorBoundaryTest < TestCase
    # 上流のレスポンスを添えた GatewayError を投げる http のスタブ。
    class FailingHTTP
      Response = Struct.new(:code, :body)

      def initialize(code, body)
        @response = Response.new(code, body)
      end

      def upload(*)
        error = Ginseng::GatewayError.new("Bad response #{@response.code}")
        error.response = @response
        raise error
      end
    end

    def upload(code, body = '{}')
      service = Ginseng::Fediverse::MastodonService.new(Ginseng::URI.parse('https://precure.ml/'))
      service.instance_variable_set(:@http, FailingHTTP.new(code, body))
      return service.upload('/path/to/image.jpg')
    end

    # 眼目。これが GatewayError でないと controller の rescue に掛からない。
    def test_upload_failure_is_a_gateway_error
      assert_raise(Ginseng::GatewayError) {upload(401)}
    end

    # ⚠ ValidateError は RequestError の子で GatewayError の子ではない。
    def test_upload_failure_is_not_a_validate_error
      error = assert_raise(Ginseng::GatewayError) {upload(401)}

      assert_false(error.is_a?(Ginseng::ValidateError))
    end

    # source_status が取れないと silent_statuses の判定ができない。
    def test_source_status_reaches_the_controller
      error = assert_raise(Ginseng::GatewayError) {upload(401)}

      assert_equal(401, error.source_status)
    end

    # 413 は「上限サイズ超過」の利用者向け文言の分岐条件。
    def test_size_limit_status_reaches_the_controller
      error = assert_raise(Ginseng::GatewayError) {upload(413)}

      assert_equal(413, error.source_status)
    end

    # 上流が返した理由もプロキシの中で失われないこと。
    def test_upstream_reason_reaches_the_controller
      error = assert_raise(Ginseng::GatewayError) do
        upload(422, {error: 'Validation failed: File type is invalid'}.to_json)
      end

      assert_equal('Validation failed: File type is invalid', error.source_body['error'])
    end
  end
end
