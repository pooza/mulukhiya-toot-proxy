module Mulukhiya
  # `POST /account/is_cat` の本体 (#4677)。
  #
  # ⚠⚠ **失敗もキャッシュする。**以前は取れなかった acct を Redis に書かなかったので、
  # TCP に応答しない（RST を返さない）ホストの acct が通知一覧に居続ける限り、
  # 呼び出しのたびに接続タイムアウトまで塞がった。ダイスキーで 504、美食丼で 499
  # （capsicum が 5 秒で切る）として出ていた。失敗の寿命は成功より短くし、相手が
  # 戻れば次の機会に取り直す。
  #
  # ⚠ **is_cat は猫耳の表示のための装飾なので、早く諦めてよい。**既定の HTTP は
  # 30 秒 × 3 回まで粘るので、ここだけ `/account/is_cat/timeout` 秒・再送なしにする。
  # ⚠⚠ **締切は 1 件の取得全体（WebFinger ＋ actor）に掛ける（PR #4842 の Codex P1）。**
  # 要求ごとに数え直すと 2 倍まで延び、capsicum が 5 秒で切るのに間に合わない。
  # 2 回目の要求には残り時間だけを渡す。
  #
  # ⚠⚠ **要求全体にも締切を 1 つ置く（PR #4842 の Codex P1・3 件目）。**acct は最大 50 件で、
  # スレッドは CPU 数（本番 4）なので、応答しない相手が並ぶと 4 秒の波が続いて 50 秒を超えた。
  # 締切を過ぎた acct は取りに行かずに nil を返し、**覚えない**（試していない）。
  # ⚠ 要求全体の締切で時間を削られた回の失敗も覚えない。生きている相手を 10 分「猫ではない」
  # にしてしまうため。自分の持ち時間をほぼ使えた回（削られ方が `SHORTENED_MARGIN` 秒未満）だけ覚える。
  class IsCatService
    include Package

    SHORTENED_MARGIN = 0.5

    def initialize(storage: IsCatStorage.new, http: nil)
      @storage = storage
      @http = http || create_http
    end

    # ⚠ 要求全体の締切で打ち切った acct は、要求ごとに 1 行だけ数を残す。打ち切りは
    # 「相手が失敗した」（`fetch_actor` が log する）と違って何も残らず、猫耳が出ない理由を
    # syslog から追えなかった（5.43.0 のリリース前レビュー）。
    def resolve(accts)
      deadline = monotonic + timeout
      @skipped = Concurrent::AtomicFixnum.new
      result = Concurrent::Hash.new
      Parallel.each(accts.uniq, in_threads: Parallel.processor_count) do |acct_str|
        result[acct_str] = lookup(acct_str, deadline)
      rescue => e
        e.log(acct: acct_str)
        result[acct_str] = nil
      end
      if @skipped.value.positive?
        logger.info(
          class: self.class.to_s,
          message: 'deadline exceeded',
          skipped: @skipped.value,
          accts: result.size,
        )
      end
      return result
    end

    def lookup(acct_str, deadline = nil)
      if cached = @storage.get(acct_str)
        return cached['is_cat']
      end
      own = monotonic + timeout
      deadline ||= own
      unless deadline > monotonic
        @skipped&.increment
        return nil
      end
      actor = fetch_actor(Ginseng::Fediverse::Acct.new(acct_str), [deadline, own].min)
      if actor.nil?
        @storage.remember_failure(acct_str) unless deadline < own - SHORTENED_MARGIN
        return nil
      end
      is_cat = actor['isCat']
      @storage.set(acct_str, {is_cat:})
      return is_cat
    end

    # ⚠⚠ **名前解決も締切の内側に入れる（PR #4842 の Codex P1・2 件目）。**
    # `RemoteHost.validate!` と、要求ごと・転送ごとの `host_validator` は独自の締切
    # （`/remote_host/dns/timeout`）で名前を引くので、HTTP に残り時間を渡すだけでは
    # 収まらない。取得全体を `Timeout.timeout` で包み、HTTP には残り時間も渡す
    # （ソケットを締切どおりに閉じるため）。
    def fetch_actor(acct, deadline = nil)
      deadline ||= monotonic + timeout
      budget = deadline - monotonic
      raise Ginseng::GatewayError, 'is_cat deadline exceeded' unless budget.positive?
      return Timeout.timeout(budget) do
        RemoteHost.validate!(acct.host)
        url = "https://#{acct.host}/.well-known/webfinger?resource=acct:#{acct}"
        webfinger = fetch_json(url, 'application/jrd+json', deadline)
        actor_uri = webfinger['links']&.find do |l|
          l['type'] == 'application/activity+json'
        end&.dig('href')
        next nil unless actor_uri
        RemoteHost.validate!(Ginseng::URI.parse(actor_uri)&.host.to_s)
        next fetch_json(actor_uri, 'application/activity+json', deadline)
      end
    rescue => e
      e.log(acct: acct.to_s)
      return nil
    end

    private

    def timeout
      return config['/account/is_cat/timeout']
    end

    def monotonic
      return Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def create_http
      http = HTTP.new
      http.timeout = timeout
      http.retry_limit = 1
      return http
    end

    def fetch_json(url, accept, deadline)
      remaining = deadline - monotonic
      raise Ginseng::GatewayError, 'is_cat deadline exceeded' unless remaining.positive?
      response = @http.get(url, {
        headers: {'Accept' => accept},
        host_validator: RemoteHost.validator,
        timeout: remaining,
      }).parsed_response
      return response.is_a?(String) ? JSON.parse(response) : response
    end
  end
end
