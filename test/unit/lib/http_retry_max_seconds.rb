module Mulukhiya
  # 上流の 429 が示す待ち時間に付き合う上限 (/http/retry/max_seconds)。
  #
  # ⚠ ginseng-core v1.25.1 から、待ち時間が上限以内なら**そのあいだ眠ってから**叩き直す。
  # 既定は 60 秒で、眠っているあいだ puma のスレッドを持ったままになる。設定が消えると
  # 黙って 60 秒へ戻るので、キーがあることと gem がそれを読むことを押さえる
  # （5.39.0 のリリース前レビュー）。
  class HTTPRetryMaxSecondsTest < TestCase
    def test_config
      assert_equal(5, config['/http/retry/max_seconds'])
    end

    def test_http_reads_config
      assert_equal(5, HTTP.new.__send__(:max_retry_seconds))
    end
  end
end
