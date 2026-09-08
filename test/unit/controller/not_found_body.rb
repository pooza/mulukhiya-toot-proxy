require 'rack/test'

module Mulukhiya
  # `not_found` がルート由来の 404 ボディを差し替えないこと (#4520)。
  #
  # ⚠⚠ **Sinatra は `response.status == 404` を見て、ルートが正常に返った後でも
  # `not_found` block を呼ぶ**（`invoke { error_block!(response.status) }`）。
  # そのためルートの `rescue` が組み立てた `{error: e.message}` が毎回既定メッセージで
  # 上書きされ、**`APIController` の 404 は事実上デッドコード**になっていた。
  #
  # 🔴 403/422/5xx は `error` / `errors` キーを持つのに 404 だけ
  # `{package, class, message}` になるので、**クライアントがキーの有無で分岐できない**。
  class NotFoundBodyTest < TestCase
    include Rack::Test::Methods

    ROUTE_MESSAGE = 'Status not found or not yours.'.freeze

    # ⚠ Sinatra は環境によって `raise_errors` / `show_exceptions` の既定が変わる。
    # 見たいのは `not_found` block のふるまいなので、両方を明示的に落として固定する。
    class NotFoundProbeController < Controller
      set :raise_errors, false
      set :show_exceptions, false

      # ルート側のローカル rescue が組み立てる形をそのまま再現する。
      get '/rescued' do
        @renderer.status = 404
        @renderer.message = {error: ROUTE_MESSAGE}
        return @renderer.to_s
      end

      # message を持たないレンダラへ差し替えたまま 404 になる経路。
      get '/raw' do
        @renderer = Ginseng::Web::RawRenderer.new
        @renderer.status = 404
        return @renderer.to_s
      end
    end

    def app = NotFoundProbeController

    # 🔴 **本体。**ルートが書いた body がそのまま返る。
    def test_route_body_survives
      body = request('/rescued')

      assert_equal(ROUTE_MESSAGE, body['error'])
      assert_equal(404, last_response.status)
    end

    # ⚠ **退行の目印。**既定メッセージへ潰れていないこと。
    def test_route_body_is_not_replaced_by_the_default
      body = request('/rescued')

      assert_nil(body['class'])
      assert_nil(body['package'])
      assert_not_match(/not found\.\z/, body['error'].to_s)
    end

    # ルート未一致は従来どおり既定メッセージ。⚠ ここを壊すと 404 が空になる。
    def test_route_miss_still_gets_the_default_body
      body = request('/nonexistent')

      assert_equal('Ginseng::NotFoundError', body['class'])
      assert_match(%r{Resource /nonexistent not found\.}, body['message'].to_s)
      assert_equal(404, last_response.status)
    end

    # ⚠ message を持たないレンダラでも落ちない（`respond_to?` のガード）。
    def test_renderer_without_message_falls_back
      body = request('/raw')

      assert_equal('Ginseng::NotFoundError', body['class'])
      assert_equal(404, last_response.status)
    end

    private

    # ⚠ Sinatra のホスト認可で 403 になるので Host を明示する。
    # ⚠ **Rack 3 では `rack.input` が任意**で、rack-test は省略する。省略すると
    # `before` の `request.body.read` が落ち、before ごと飛んでしまう。
    def request(path)
      get(path, {}, 'HTTP_HOST' => 'localhost', 'rack.input' => StringIO.new(''))
      return JSON.parse(last_response.body)
    rescue JSON::ParserError
      return {}
    end
  end
end
