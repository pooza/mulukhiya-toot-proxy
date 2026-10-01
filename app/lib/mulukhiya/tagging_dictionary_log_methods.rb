module Mulukhiya
  # タグ辞書の観測ログ (#4583 / #4573)。TaggingDictionary 本体から切り出してある。
  #
  # ⚠ **切り出したのは行数合わせではなく、辞書の「取り込みロジック」と
  # 「取り込みが健全だったかの記録」を混ぜないため。**タグ辞書は失敗を握って空を
  # 返す層が何段もあるので、どこで何を残したかが本体のコードに埋もれると、
  # #4573 のような「黙って空になる」をまた見落とす。
  module TaggingDictionaryLogMethods
    private

    # どの取得回の辞書を使っているかをログに残す。実走のたびに世代が出るので、
    # 「前の実行が温めたキャッシュを読んでいる」状態を後から突き合わせられる。
    #
    # ⚠ **空だったソースの本数も一緒に出す (#4573)。**1 行で「何本中何本が
    # 死んでいるか」が読めないと、辞書が痩せていることに気付けない。1 本でも
    # 空なら error で出す（更新自体は成功しているので message は変えない）。
    def log_generation
      empty = @empty_sources.to_a
      # ⚠ **last-good で埋めた本数も出す (#4659 の ②)。**`empty_sources` と
      # `entries` だけだと、「痩せた辞書で更新した回」と「埋めたので痩せずに
      # 済んだ回」が同じ見え方になる。
      substituted = @substituted_sources.to_a
      payload = {
        message: 'tagging dictionary refreshed',
        redis_key: TaggingDictionary::REDIS_KEY,
        signature:,
        generated_at: generated_at&.iso8601,
        sources: sources.size,
        # ⚠ **実際に試した本数も出す (#4628 の 4 件目)。**`sources` は設定の本数で、
        # `RemoteDictionary.create` が落ちた本（`type:` の打ち間違い等）は
        # 試されないまま `empty_sources` にも入らず、「健全」に見える。
        attempted_sources: @attempted_sources.to_i,
        empty_sources: empty.size,
        substituted_sources: substituted.size,
        entries: size,
        ttl: cache_ttl,
      }
      return logger.info(payload) if empty.empty?
      # どのソースを last-good で埋めたか (#4628 の 8 件目)。本数だけだと、
      # 埋めた辞書の鮮度を台帳と突き合わせられない。
      logger.error(payload.merge(empty_source_urls: empty, substituted_source_urls: substituted))
    end

    # 直近の good を残して戻った回の記録 (#4659)。
    #
    # ⚠⚠ **`log_generation` を流用しないこと。**あれは
    # `tagging dictionary refreshed` ＝ **更新に成功した回**の記録なので、据え置きを
    # そこへ混ぜると「据え置きを更新成功として記録する」形になる（#4628 で挙げた
    # 穴と同型で、元より悪い）。
    #
    # ⚠ **従来はこの回が syslog に 1 行も残らなかった。**`refresh` が
    # `log_generation` の手前で return するので、「1 本欠けただけ」に見えて
    # **全滅したことが分からない**状態だった（#4628 の 6 件目）。
    def log_retention
      logger.error(
        message: 'tagging dictionary retained',
        redis_key: TaggingDictionary::REDIS_KEY,
        signature:,
        generated_at: generated_at&.iso8601,
        sources: sources.size,
        attempted_sources: @attempted_sources.to_i,
        empty_sources: @empty_sources.to_a.size,
        substituted_sources: @substituted_sources.to_a.size,
        empty_source_urls: @empty_sources.to_a,
        entries: size,
      )
    end

    # `refresh` が例外で落ちた回の記録 (#4628 の 7 件目)。
    #
    # ⚠ **設定の読みは握る。**落ちた原因が設定の読み（`Handler.create` /
    # `handler.all`）かもしれないので、`sources` / `signature` がここでもう一度
    # 落ちうる。落ちた項目は nil にして、1 行は必ず残す。
    def log_failure(error)
      logger.error(
        message: 'tagging dictionary refresh failed',
        redis_key: TaggingDictionary::REDIS_KEY,
        error: error.class.name,
        signature: (signature rescue nil),
        sources: (sources.size rescue nil),
        attempted_sources: @attempted_sources,
        empty_sources: @empty_sources&.size,
        substituted_sources: @substituted_sources&.size,
        entries: size,
      )
    rescue => e
      e.log
    end

    def alert_empty_result
      Ginseng::GatewayError.new('tagging dictionary fetch returned nothing').alert(
        redis_key: TaggingDictionary::REDIS_KEY,
        sources: sources.count,
        cached_entries: cache.to_h.size,
        generated_at: generated_at&.iso8601,
      )
    end
  end
end
