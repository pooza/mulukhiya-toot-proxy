module Mulukhiya
  # 辞書ソース取得だけが 404 を再送すること (#4689)。
  #
  # ⚠⚠ **`Mulukhiya::HTTP` 全体で 404 を retryable にしてはいけない。**投稿経路や
  # API クライアントまで巻き込むと、**恒久的な 404 を retry_limit 倍叩き直すだけ**に
  # なる。上流（`Ginseng::HTTP::RetryMethods#retryable?`）が 404 を外しているのは
  # 意図的な設計で、一般論としては正しい。404 が一時的なのは **GAS という相手の事情**。
  class DictionaryHTTPTest < TestCase
    RETRY_KEY = '/handler/dictionary_tag/retry/limit'.freeze

    def setup
      @dic = DictionaryHTTP.new
      @plain = HTTP.new
      @limit = config[RETRY_KEY] rescue nil
    end

    def teardown
      config[RETRY_KEY] = @limit
    end

    # 🔴 **本体。**辞書用クライアントは 404 を再送する。
    def test_dictionary_retries_not_found
      assert(retryable?(@dic, 404), '辞書が 404 を再送しない')
    end

    # 🔴 **本体その 2。**⚠ 素の `Mulukhiya::HTTP` は巻き込まない。
    # ここが true になったら、恒久的な 404 を全経路で叩き直している。
    def test_plain_http_does_not_retry_not_found
      refute(retryable?(@plain, 404), '投稿経路まで 404 を再送している')
    end

    # ⚠ 開けたのは 404 だけ。他の恒久的な 4xx は上流の判定のまま。
    def test_other_client_errors_stay_permanent
      [400, 401, 403, 410, 422].each do |status|
        refute(retryable?(@dic, status), "#{status} まで再送対象になっている")
      end
    end

    # ⚠ **上流の判定を殺していない。**5xx と一時的な 4xx は従来どおり再送する。
    def test_upstream_policy_is_preserved
      [408, 425, 429, 500, 502, 503].each do |status|
        assert(retryable?(@dic, status), "#{status} が再送されなくなっている")
      end
    end

    # 🔴 **上流のガードをすり抜けない**（PR #4710 の Codex P1）。
    # ⚠⚠ `PinningError` / `TooLargeError` は **`GatewayError` のサブクラス**なので、
    # `is_a?` で拾うと **`source_status` がたまたま 404 のときに再送してしまう**。
    # pinning は設定の問題で試行の間に変わらず、上限超過は同じ場所で超えるだけ。
    def test_upstream_guards_are_not_bypassed
      [Ginseng::PinningError, Ginseng::TooLargeError].each do |klass|
        error = klass.new('boom')
        error.define_singleton_method(:source_status) {404}

        refute(@dic.send(:retryable?, error), "#{klass} が 404 で再送対象になっている")
      end
    end

    # ⚠ ガードは `GatewayError` のサブクラスとして足される。列挙せず
    # `instance_of?` で見ているので、上流が増やしても自動で追随する。
    def test_guards_are_gateway_error_subclasses
      [Ginseng::PinningError, Ginseng::TooLargeError].each do |klass|
        assert_operator(klass, :<, Ginseng::GatewayError)
      end
    end

    # ⚠ **`retry_limit` の reader を潰していない。**呼び出し側の
    # `http.retry_limit = 1` が効かなくなると、絞ったつもりの経路が黙って戻る。
    def test_retry_limit_stays_assignable
      @dic.retry_limit = 1

      assert_equal(1, @dic.retry_limit)
    end

    # 既定は設定から引く。⚠ 死にコードだった `RemoteDictionary#retry_limit` は
    # `rescue 5` という**別の既定値**を持っていて「辞書だけ 5 回」に見えていた。
    def test_default_comes_from_config
      config[RETRY_KEY] = 4

      assert_equal(4, DictionaryHTTP.new.retry_limit)
    end

    # 設定が無い環境でも「制限なし」や nil に退行しない。
    def test_falls_back_to_the_constant
      config[RETRY_KEY] = nil
      assert_raises(Ginseng::ConfigError) {config[RETRY_KEY]}

      assert_equal(DictionaryHTTP::DEFAULT_RETRY_LIMIT, DictionaryHTTP.new.retry_limit)
    end

    # 🔴 **死にコードが復活していないこと。**`RemoteDictionary#retry_limit` は
    # `rescue 5` の別既定を持つ未使用メソッドだった（#4689 で削除）。
    def test_remote_dictionary_has_no_stale_retry_limit
      refute(RemoteDictionary.method_defined?(:retry_limit, false))
    end

    private

    # `retryable?` は private なので送る。error は source_status だけ見られる。
    def retryable?(http, status)
      return http.send(:retryable?, gateway_error(status))
    end

    def gateway_error(status)
      error = Ginseng::GatewayError.new("Bad response #{status}")
      error.define_singleton_method(:source_status) {status}
      return error
    end
  end
end
