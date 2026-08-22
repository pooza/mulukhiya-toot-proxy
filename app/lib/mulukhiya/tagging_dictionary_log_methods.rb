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
      payload = {
        message: 'tagging dictionary refreshed',
        redis_key: TaggingDictionary::REDIS_KEY,
        signature:,
        generated_at: generated_at&.iso8601,
        sources: sources.size,
        empty_sources: empty.size,
        entries: size,
        ttl: cache_ttl,
      }
      return logger.info(payload) if empty.empty?
      logger.error(payload.merge(empty_source_urls: empty))
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
