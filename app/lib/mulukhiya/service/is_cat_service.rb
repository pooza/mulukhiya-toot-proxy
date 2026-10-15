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
  class IsCatService
    include Package

    def initialize(storage: IsCatStorage.new, http: nil)
      @storage = storage
      @http = http || create_http
    end

    def resolve(accts)
      result = Concurrent::Hash.new
      Parallel.each(accts.uniq, in_threads: Parallel.processor_count) do |acct_str|
        result[acct_str] = lookup(acct_str)
      rescue => e
        e.log(acct: acct_str)
        result[acct_str] = nil
      end
      return result
    end

    def lookup(acct_str)
      if cached = @storage.get(acct_str)
        return cached['is_cat']
      end
      actor = fetch_actor(Ginseng::Fediverse::Acct.new(acct_str))
      if actor.nil?
        @storage.remember_failure(acct_str)
        return nil
      end
      is_cat = actor['isCat']
      @storage.set(acct_str, {is_cat:})
      return is_cat
    end

    def fetch_actor(acct)
      RemoteHost.validate!(acct.host)
      url = "https://#{acct.host}/.well-known/webfinger?resource=acct:#{acct}"
      webfinger = fetch_json(url, 'application/jrd+json')
      actor_uri = webfinger['links']&.find do |l|
        l['type'] == 'application/activity+json'
      end&.dig('href')
      return nil unless actor_uri
      RemoteHost.validate!(Ginseng::URI.parse(actor_uri)&.host.to_s)
      return fetch_json(actor_uri, 'application/activity+json')
    rescue => e
      e.log(acct: acct.to_s)
      return nil
    end

    private

    def create_http
      http = HTTP.new
      http.timeout = config['/account/is_cat/timeout']
      http.retry_limit = 1
      return http
    end

    def fetch_json(url, accept)
      response = @http.get(url, {
        headers: {'Accept' => accept},
        host_validator: RemoteHost.validator,
      }).parsed_response
      return response.is_a?(String) ? JSON.parse(response) : response
    end
  end
end
