module Mulukhiya
  # 番組表の取得が全滅したことを syslog から読めるか (#4577 の 1)。
  #
  # ⚠⚠ **従来、全滅しても「全滅した」と読める行が 1 本も無かった。**
  # `fetch_remote` は黙って nil を返し、`update` は save をスキップし、
  # ProgramUpdateWorker はその後 `programs: 42` を出す。この件数は
  # last-known-good なので**成功した回と出力が完全に同一**で、番組表が古いまま
  # 凍結していても実況当日まで誰も気づけなかった。
  #
  # ⚠ ProgramFetcherTest へは足さない。あちらは `livecure?` が false の環境で
  # 丸ごと omit されるため、番組表を持たないサーバーでは一度も検査されない
  # （[ProgramAnnictStalenessTest](program_annict_staleness.rb) と同じ理由）。
  # ここは HTTP を撃たないので、どの環境でも必ず走る。
  class ProgramFetchObservabilityTest < TestCase
    def setup
      @fetcher = ProgramFetcher.new
      @logged = []
      logged = @logged
      double = Object.new
      double.define_singleton_method(:error) {|payload| logged.push(payload)}
      @fetcher.define_singleton_method(:logger) {double}
    end

    def log_failure(attempted, failed)
      @fetcher.send(:log_fetch_failure, attempted, failed)
      return @logged.last
    end

    # ⚠⚠ 本丸。全滅した回が「全滅した」と読める語で残ること。
    def test_exhausted_is_distinguishable
      payload = log_failure(2, ['http://a.example.com/', 'http://b.example.com/'])

      assert_equal('program fetch exhausted', payload[:message])
      assert_equal(2, payload[:attempted])
      assert_equal(2, payload[:failed])
    end

    # ⚠ 一部だけ落ちた回と混ぜない。同じ語にすると「1 本欠けただけ」と
    # 「全部死んだ」が同じ見え方に戻る（#4628 の 6 件目と同型）。
    def test_partial_failure_is_degraded
      assert_equal('program fetch degraded', log_failure(3, ['http://a.example.com/'])[:message])
    end

    # ⚠ どの URL が死んでいるかまで出す。本数だけだと直しに行けない。
    def test_failed_urls_are_listed
      payload = log_failure(3, ['http://a.example.com/'])

      assert_equal(['http://a.example.com/'], payload[:failed_urls])
    end

    # ⚠⚠ **呼び出し側が消えても気づけるようにする。**`log_fetch_failure` 単体の
    # テストだけだと、`fetch_remote` からの呼び出しを外しても緑のまま
    # 「全滅は無音」に戻る（#4578 で踏んだ「検査していないのに緑」と同じ型）。
    #
    # HTTP は撃たない。`valid_content_length?` を false に倒して
    # 「取れなかった」だけを作る。
    def test_fetch_remote_logs_when_every_url_fails
      uris = ['http://a.example.com/', 'http://b.example.com/']
        .filter_map {|v| Ginseng::URI.parse(v)}.to_set
      @fetcher.define_singleton_method(:uris) {uris}
      @fetcher.define_singleton_method(:valid_content_length?) {|_uri| false}

      assert_nil(@fetcher.send(:fetch_remote), '全滅しているのに last-known-good を捨てている')
      assert_equal('program fetch exhausted', @logged.last[:message])
      assert_equal(2, @logged.last[:failed])
    end

    # ⚠ **「1 本でも取れたら last-known-good を捨てない」側はここでは作れない。**
    # `RemoteHost.validate!` が `example.com` を allowlist で弾くので、
    # 到達する前に全滅してしまう（実ホストを使うと HTTP を撃つことになる）。
    # 部分失敗の語は上の `test_partial_failure_is_degraded` が直接見ている。
  end
end
