module Mulukhiya
  # 上流のエラー応答の待ち時間ヘッダがクライアントまで届くこと (#4775)。
  #
  # 🔴 Mastodon は 429 に `Retry-After` を付けず、`X-RateLimit-Reset` だけを返す。
  # 中継しないと、経由したクライアント（pooza/makoto2 の MAKOTO など）は窓を読めず、
  # 固定の間隔で叩き直して規制を長引かせる。
  class UpstreamHeaderRelayTest < TestCase
    # HTTParty::Response と同じく `headers` を持つダブル。
    HTTPartyDouble = Struct.new(:code, :body, :headers)
    RESET = '2026-09-28T10:05:00.000Z'.freeze

    def setup
      @controller = MastodonController.new!
      @renderer = Ginseng::Web::JSONRenderer.new
      @response = Sinatra::Response.new
      @controller.instance_variable_set(:@renderer, @renderer)
      @controller.instance_variable_set(:@response, @response)
    end

    # 本丸。Mastodon の 429 の形（Retry-After 無し・ヘッダ名は小文字）で届くこと。
    def test_relays_ratelimit_headers_as_mastodon_sends_them
      handle(build_error(429, {
        'x-ratelimit-limit' => ['300'],
        'x-ratelimit-remaining' => ['0'],
        'x-ratelimit-reset' => [RESET],
      }))

      assert_equal(429, @renderer.status)
      assert_equal(RESET, @response.headers['X-RateLimit-Reset'])
      assert_equal('300', @response.headers['X-RateLimit-Limit'])
      assert_equal('0', @response.headers['X-RateLimit-Remaining'])
      assert_nil(@response.headers['Retry-After'], '上流に無い Retry-After を作らない')
    end

    def test_relays_retry_after
      handle(build_error(429, {'retry-after' => ['120']}))

      assert_equal('120', @response.headers['Retry-After'])
    end

    # ⚠ `Net::HTTPResponse` は `headers` を持たず `response[name]` で読む
    # （pooza/ginseng-core#549 と同じ事情）。
    def test_relays_from_net_http_response
      response = Net::HTTPTooManyRequests.new('1.1', '429', 'Too Many Requests')
      response['x-ratelimit-reset'] = RESET
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, '{}')
      error = Ginseng::GatewayError.new('Bad response 429')
      error.response = response
      handle(error)

      assert_equal(RESET, @response.headers['X-RateLimit-Reset'])
    end

    # ⚠ 許可リストに無いヘッダは持ち込まない。
    def test_does_not_relay_other_headers
      handle(build_error(429, {'set-cookie' => ['session=x'], 'x-ratelimit-reset' => [RESET]}))

      assert_nil(@response.headers['Set-Cookie'])
    end

    # ⚠ 他人のサーバー由来 (#4537) は 502 に倒すので、待ち時間も渡さない。
    # 渡すと「モロヘイヤの上流が規制している」と読まれる。
    def test_does_not_relay_for_foreign_gateway_error
      error = ForeignGatewayError.wrap(build_error(429, {'x-ratelimit-reset' => [RESET]}))
      handle(error)

      assert_equal(502, @renderer.status)
      assert_nil(@response.headers['X-RateLimit-Reset'])
    end

    # ⚠ 改行を含む値は応答ヘッダの分割になるので捨てる。Net::HTTP のヘッダは
    # 改行を受け付けないので、ここは素の Hash を持つダブルで通す（念のための守り）。
    def test_drops_value_with_newline
      error = Ginseng::GatewayError.new('Bad response 429')
      headers = {'X-RateLimit-Reset' => "#{RESET}\r\nX-Injected: 1"}
      error.response = HTTPartyDouble.new(429, '{}', headers)
      handle(error)

      assert_nil(@response.headers['X-RateLimit-Reset'])
    end

    # ヘッダの無い上流エラーは今までどおり（何も足さない）。
    def test_nothing_to_relay
      handle(build_error(422, {}))

      assert_equal(422, @renderer.status)
      assert_empty(@response.headers.keys.grep(/ratelimit|retry-after/i))
    end

    private

    def build_error(code, header_values)
      error = Ginseng::GatewayError.new("Bad response #{code}")
      headers = HTTParty::Response::Headers.new(header_values)
      error.response = HTTPartyDouble.new(code, {error: 'Too many requests'}.to_json, headers)
      return error
    end

    # Sentry へ実際に送らないよう alert / log を差し替えてから通す。
    def handle(error)
      error.define_singleton_method(:alert) {|**_opts| nil}
      error.define_singleton_method(:log) {|**_opts| nil}
      @controller.handle_gateway_error(error)
    end
  end
end
