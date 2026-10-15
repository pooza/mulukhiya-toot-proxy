module Mulukhiya
  # `POST /account/is_cat` の本体 (#4677)。
  #
  # ⚠ ストレージと actor の取得を差し替えるだけなので、Redis も外への通信も要らない。
  class IsCatServiceTest < TestCase
    ACCT = 'a@example.com'.freeze

    class FakeStorage
      attr_reader :sets, :failures

      def initialize(entry = nil)
        @entry = entry
        @sets = {}
        @failures = []
      end

      def get(_acct)
        return @entry
      end

      def set(acct, value)
        @sets[acct] = value
      end

      def remember_failure(acct)
        @failures.push(acct)
      end
    end

    def create_service(storage, actor: nil, fetcher: nil)
      service = IsCatService.new(storage:, http: Object.new)
      calls = []
      service.define_singleton_method(:fetch_actor) do |acct|
        calls.push(acct.to_s)
        next fetcher ? fetcher.call(acct) : actor
      end
      return service, calls
    end

    def setup
      @original_validator = RemoteHost.validator
      RemoteHost.validator = ->(_host) {'93.184.216.34'}
    end

    def teardown
      super
      RemoteHost.validator = @original_validator
    end

    # ⚠⚠ **本命。**取れなかった acct も覚える。覚えないと、応答しないホストの acct で
    # 呼び出しのたびに締切まで待たされる（ダイスキーの 504・美食丼の 499）。
    def test_failure_is_cached
      storage = FakeStorage.new
      service, = create_service(storage, actor: nil)

      assert_nil(service.lookup(ACCT))
      assert_equal([ACCT], storage.failures)
      assert_empty(storage.sets)
    end

    # 覚えた失敗に当たったら、取りに行かない。
    def test_cached_failure_is_not_refetched
      storage = FakeStorage.new({'is_cat' => nil, 'failed' => true})
      service, calls = create_service(storage, actor: {'isCat' => true})

      assert_nil(service.lookup(ACCT))
      assert_empty(calls)
    end

    def test_success_is_cached
      storage = FakeStorage.new
      service, = create_service(storage, actor: {'isCat' => true})

      assert_true(service.lookup(ACCT))
      assert_equal({ACCT => {is_cat: true}}, storage.sets)
      assert_empty(storage.failures)
    end

    # isCat が無い actor は失敗ではない（取れたうえで「猫ではない」）。成功の寿命で覚える。
    def test_actor_without_is_cat_is_a_success
      storage = FakeStorage.new
      service, = create_service(storage, actor: {})

      assert_nil(service.lookup(ACCT))
      assert_equal({ACCT => {is_cat: nil}}, storage.sets)
      assert_empty(storage.failures)
    end

    # 1 件が例外を上げても、ほかの acct の結果は返る。
    def test_resolve_isolates_errors
      storage = FakeStorage.new
      fetcher = lambda do |acct|
        raise 'boom' if acct.to_s == 'b@example.com'
        next {'isCat' => true}
      end
      service, = create_service(storage, fetcher:)
      result = service.resolve([ACCT, 'b@example.com', ACCT])

      assert_equal({ACCT => true, 'b@example.com' => nil}, result.to_h)
    end

    # ⚠⚠ 締切は取得全体に 1 つ（PR #4842 の Codex P1）。actor には残り時間だけを渡す。
    def test_actor_request_gets_only_the_remaining_time
      timeouts = []
      service = create_deadline_service(timeouts, [100.0, 100.0, 103.0])

      assert_true(service.fetch_actor(Ginseng::Fediverse::Acct.new(ACCT))['isCat'])
      assert_equal([4.0, 1.0], timeouts)
    end

    # 締切を過ぎたら actor を取りに行かない（失敗として覚えられる）。
    def test_actor_is_not_requested_after_the_deadline
      timeouts = []
      service = create_deadline_service(timeouts, [100.0, 100.0, 104.5])

      assert_nil(service.fetch_actor(Ginseng::Fediverse::Acct.new(ACCT)))
      assert_equal([4.0], timeouts)
    end

    # ⚠⚠ 名前解決が遅くても締切で諦める（PR #4842 の Codex P1・2 件目）。
    def test_slow_dns_is_bounded_by_the_deadline
      service = create_deadline_service([], [100.0, 100.0, 100.0])
      service.define_singleton_method(:timeout) {0.2}
      RemoteHost.validator = lambda do |_host|
        sleep(2)
        next '93.184.216.34'
      end
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_nil(service.fetch_actor(Ginseng::Fediverse::Acct.new(ACCT)))
      assert_operator(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1)
    end

    # ⚠ 装飾なので早く諦める。既定の HTTP（30 秒 × 3 回）のままにしない。
    def test_http_gives_up_early
      http = IsCatService.new(storage: FakeStorage.new).instance_variable_get(:@http)

      assert_equal(config['/account/is_cat/timeout'], http.timeout)
      assert_operator(http.timeout, :<, config['/http/timeout/seconds'])
      assert_equal(1, http.retry_limit)
    end

    private

    # 時計と締切（4 秒）を差し替え、HTTP へ渡った締切を集める。
    def create_deadline_service(timeouts, clock)
      http = Object.new
      http.define_singleton_method(:get) do |url, options|
        timeouts.push(options[:timeout])
        body = url.include?('webfinger') ? {links: [{type: 'application/activity+json', href: 'https://example.com/a'}]} : {isCat: true}
        next Struct.new(:parsed_response).new(JSON.parse(body.to_json))
      end
      service = IsCatService.new(storage: FakeStorage.new, http:)
      service.define_singleton_method(:monotonic) {clock.shift}
      service.define_singleton_method(:timeout) {4}
      return service
    end
  end
end
