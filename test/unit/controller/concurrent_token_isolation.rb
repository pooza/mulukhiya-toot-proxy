require 'net/http'
require 'puma'
require 'puma/server'

module Mulukhiya
  # 同時アクセス下でトークンが取り違えられないことの回帰テスト (#4678)。
  #
  # 2025-10 の事故（rack 3.2.3 + sinatra 4.2.0・他人のトークンで投稿が出た）の再発を、
  # **版を上げる前に手元と CI で**見るためのもの。正本は
  # `docs/archive/postmortem-2025-10-rack32.md`。
  #
  # ⚠⚠ **これが緑でも「安全」の証明にはならない。**事故の原因は未特定で、再現条件が
  # 分かっていない。守れるのは「いまの実装で取り違えが起きない」ことの回帰まで。
  # 🔴 **事故の版（rack 3.2.3 + sinatra 4.2.0）へ下げても緑だった**（2026-10-12 実測・
  # puma 8.0.2 / Ruby 4.0.7・3 回）。＝このテストは**あの事故を再現しない**。
  # 「緑だから 4.3 系へ上げてよい」とは読めない。ステージングの通し確認は省かない。
  #
  # ⚠ **`verify_token_integrity!` が効いているだけの状態を緑にしない。**あれは本番の
  # 防御策なので、「発火したら 403 で止まる」だけを見ると、取り違えが起きていても
  # 防御が受け止めている限り気づけない。ここでは **発火が 0 回だったこと**と、
  # **上流へ出ていくトークンが自分の送ったものだったこと**を別々に確かめる。
  class ConcurrentTokenIsolationTest < TestCase
    REQUESTS = 500
    CLIENTS = 8
    # ⚠ わざと壊したプローブは**設定に依らず**複数スレッドで受ける。`/puma/threads` が 1 の
    # 環境だと直列になって混線が起きず、「仕掛けが効くことの確認」が必ず落ちる
    # （PR #4829 の Codex P2）。
    NEGATIVE_CONTROL_THREADS = 5

    # 実コントローラ（Mastodon / Misskey）を継いだプローブ。**`token` の取り出しと
    # `before` は本物**で、足すのはイベントを挟まない投稿ルートだけ（ハンドラは DB や
    # 外部 API を引くので、ここで見たいトークンの経路と混ぜない）。
    module ProbeRoutes
      def self.included(base)
        base.set :raise_errors, false
        base.set :show_exceptions, false
        base.extend(ClassMethods)
        base.post('/probe') {probe_response}
      end

      module ClassMethods
        def integrity_failures
          @integrity_failures ||= Thread::Queue.new
          return @integrity_failures
        end

        # ⚠ 本物のサービスは `default_token`（テストアカウントのトークン）を DB から引く。
        # DB の無い環境（CI・手元の単体実行）でも回せるよう、そこだけを外した子を使う。
        # リクエストのトークンを載せる経路（`token=` → 上流への要求）は本物のまま。
        def probe_sns_class
          @probe_sns_class ||= Class.new(Environment.sns_class) do
            def default_token
              return nil
            end
          end
          return @probe_sns_class
        end
      end

      def sns_class
        return self.class.probe_sns_class
      end

      # 防御策の発火を数える。⚠ 握り潰さない（403 で止まるところまで本物どおり）。
      def verify_token_integrity!
        super
      rescue Ginseng::AuthError
        self.class.integrity_failures.push(request.path)
        raise
      end

      def probe_response
        verify_token_integrity!
        # 本物のルートと同じ渡し方にする（Misskey は `params[:i]` がそのまま上流へ行く）。
        upstream = if Environment.mastodon_type?
          sns.toot(params, {headers: forwarded_headers})
        else
          sns.note(params)
        end
        @renderer.message = upstream.parsed_response
        return @renderer.to_s
      end
    end

    # 🔴 **わざと壊したプローブ。**サービスを 1 個だけ作ってリクエスト間で使い回す
    # （＝事故で疑われた「状態がスレッド間で共有される」型）。このテストの仕掛けが
    # 取り違えを**本当に検出できる**ことを確かめるためだけにある。
    module SharedStateBug
      def self.included(base)
        base.extend(ClassMethods)
        base.before do
          self.class.shared.token = token
          sleep(0.005)
        end
      end

      module ClassMethods
        def shared
          @shared ||= probe_sns_class.new
          return @shared
        end
      end

      def sns
        return self.class.shared
      end

      # わざと起こした混線で alert を鳴らさない（本物は `NeverSilent` で必ず鳴る）。
      def report_error(_error, **)
      end
    end

    module NoDefence
      def verify_token_integrity!
      end
    end

    def setup
      @upstream = stub_request(:post, %r{/api/(v1/statuses|notes/create)\z}).to_return do |request|
        {
          status: 200,
          headers: {'Content-Type' => 'application/json'},
          body: {upstream_token: upstream_token(request), serial: upstream_serial(request)}.to_json,
        }
      end
    end

    def teardown
      WebMock.reset!
      super
    end

    def test_rack_call
      probe = create_probe
      app = Rack::URLMap.new('/' => probe)
      results = run_concurrently do |serial, token|
        env = Rack::MockRequest.env_for('/probe', request_options(serial, token))
        status, _headers, body = app.call(env)
        text = +''
        body.each {|chunk| text << chunk}
        body.close if body.respond_to?(:close)
        [status, text]
      end

      assert_isolated(results, probe)
    end

    # 本番と同じ積み方（Puma のスレッドプール → URLMap → コントローラ）で見る。
    # ⚠ 接続はクライアントごとに持ち回す（keep-alive）。事故の調査で挙がった Puma の
    # 情報漏洩（GHSA-rmj8-8hhh-gv5h）が keep-alive の経路だったため。
    def test_puma
      probe = create_probe
      results = with_puma(probe) do |port|
        run_concurrently do |serial, token, client|
          http = client[:http] ||= Net::HTTP.start('127.0.0.1', port)
          response = http.request(create_request(serial, token))
          [response.code.to_i, response.body]
        end
      end

      assert_isolated(results, probe)
    end

    # 🔴 **仕掛けが効くことの確認（その 1）: 防御策が受け止める。**
    def test_shared_state_is_caught_by_defence
      probe = create_probe(SharedStateBug)
      results = with_puma(probe, threads: NEGATIVE_CONTROL_THREADS) do |port|
        run_concurrently(requests: 100) do |serial, token, client|
          http = client[:http] ||= Net::HTTP.start('127.0.0.1', port)
          response = http.request(create_request(serial, token))
          [response.code.to_i, response.body]
        end
      end

      refute_predicate(probe.integrity_failures, :empty?, '防御策が 1 回も発火していない')
      assert_empty(mixed_up(results), '防御策をすり抜けて他人のトークンが上流へ出た')
    end

    # 🔴 **仕掛けが効くことの確認（その 2）: 防御策が無ければ突き合わせが見つける。**
    # ⚠ Misskey は `params[:i]` がそのまま上流へ行くので、ヘッダーで送った分だけが混ざる。
    def test_shared_state_is_detected_without_defence
      probe = create_probe(SharedStateBug, NoDefence)
      results = with_puma(probe, threads: NEGATIVE_CONTROL_THREADS) do |port|
        run_concurrently(requests: 100) do |serial, token, client|
          http = client[:http] ||= Net::HTTP.start('127.0.0.1', port)
          response = http.request(create_request(serial, token))
          [response.code.to_i, response.body]
        end
      end

      refute_empty(mixed_up(results), '取り違えを検出できていない＝このテストは事故を見逃す')
    end

    private

    def create_probe(*extras)
      probe = Class.new(controller_class)
      probe.include(ProbeRoutes)
      extras.each {|extra| probe.include(extra)}
      return probe
    end

    def with_puma(probe, threads: config['/puma/threads'])
      server = Puma::Server.new(Rack::URLMap.new('/' => probe), nil, {
        min_threads: threads,
        max_threads: threads,
        log_writer: Puma::LogWriter.null,
      })
      port = server.add_tcp_listener('127.0.0.1', 0).addr[1]
      server.run
      return yield(port)
    ensure
      server&.stop(true)
    end

    # @return [Array<Hash>] 送ったもの（serial / token）と返ってきたもの（status / body）
    def run_concurrently(requests: REQUESTS)
      queue = Thread::Queue.new
      requests.times {|serial| queue.push(serial)}
      queue.close
      results = Thread::Queue.new
      Array.new(CLIENTS) do
        Thread.new do
          client = {}
          while serial = queue.pop
            token = "probe#{serial}x#{SecureRandom.hex(12)}"
            status, body = yield(serial, token, client)
            results.push(serial:, token:, status:, body:)
          end
        ensure
          client[:http]&.finish
        end
      end.each(&:join)
      return Array.new(results.size) {results.pop}
    end

    # Misskey のクライアントは `i` を本文に入れるのが普通で、`Authorization` でも通る。
    # 両方の取り出し口を踏むよう、偶数番は本文・奇数番はヘッダーで送る。
    def body_token?(serial)
      return Environment.misskey_type? && serial.even?
    end

    def request_body(serial, token)
      body = {status_field => "serial#{serial}"}
      body[:i] = token if body_token?(serial)
      return body.to_json
    end

    def request_headers(serial, token)
      headers = {'Content-Type' => 'application/json'}
      headers['Authorization'] = "Bearer #{token}" unless body_token?(serial)
      return headers
    end

    def create_request(serial, token)
      request = Net::HTTP::Post.new('/probe', request_headers(serial, token))
      # ⚠ Sinatra のホスト認可で 403 になるので Host を明示する。
      request['Host'] = 'localhost'
      request.body = request_body(serial, token)
      return request
    end

    def request_options(serial, token)
      options = {
        :method => 'POST',
        :input => request_body(serial, token),
        'CONTENT_TYPE' => 'application/json',
        'HTTP_HOST' => 'localhost',
      }
      options['HTTP_AUTHORIZATION'] = "Bearer #{token}" unless body_token?(serial)
      return options
    end

    def upstream_payload(request)
      return JSON.parse(request.body)
    rescue
      return Rack::Utils.parse_nested_query(request.body.to_s)
    end

    def upstream_token(request)
      return upstream_payload(request)['i'] if Environment.misskey_type?
      return request.headers['Authorization'].to_s.split(/\s+/).last
    end

    def upstream_serial(request)
      return upstream_payload(request)[status_field.to_s]
    end

    def parse(result)
      return JSON.parse(result[:body])
    rescue
      return {}
    end

    # 上流へ出たトークン・本文が、送ったものと食い違っている応答。
    def mixed_up(results)
      return results.select do |result|
        next false unless result[:status] == 200
        payload = parse(result)
        payload['upstream_token'] != result[:token] || payload['serial'] != "serial#{result[:serial]}"
      end
    end

    def assert_isolated(results, probe)
      assert_equal(REQUESTS, results.size)
      assert_empty(results.reject {|v| v[:status] == 200}.map {|v| v.slice(:serial, :status, :body)}.first(3))
      assert_empty(mixed_up(results).map {|v| v[:serial]}, '他人のトークンが上流へ出た')
      assert_predicate(probe.integrity_failures, :empty?, '防御策（verify_token_integrity!）が発火した')
      assert_requested(@upstream, times: REQUESTS)
    end
  end
end
