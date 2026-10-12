module Mulukhiya
  # 本体キャッシュが無い・切れそうなときの振る舞い (#4628 の 2 件目・9 件目)。
  #
  # ⚠⚠ **決めてあるのは「投稿の経路では上流へ取りにいかない」こと。**以前は
  # `initialize` が `refresh` を同期で呼んでいたので、本体キャッシュが切れた瞬間
  # （Sidekiq が 1 時間止まる・据え置きが 1 時間続く）に、**届いた投稿すべてが**
  # 全ソースを GAS へ取りにいっていた（単一フライト無し）。Puma のスレッドが GAS の
  # 往復ぶん塞がり、そのストームで GAS が倒れると空の辞書が 1 時間ぶん書かれていた。
  #
  # 取りにいくのは更新ワーカーだけにする。投稿の経路は Redis だけで済ませる。
  module TaggingDictionaryColdCacheMethods
    private

    # 本体キャッシュが無いときの埋め方。
    #
    # 1. 更新ワーカーへ依頼を出す（`REFRESH_REQUEST_TTL` に 1 回だけ）
    # 2. ソースごとの last-good（24 時間）から組み立てる。**メモリの中だけ**で、本体
    #    キャッシュへは書かない（古い内容に「いま作った」印を付けない）
    # 3. last-good も無ければ空の辞書。⚠ **投稿は辞書タグなしで通す**（止めない）
    #
    # ⚠ development / test では `Worker.perform_async` が同期で走るので、依頼を出した
    # その場で本体キャッシュが埋まる。埋まっていればそれを使う。
    # ⚠ ここで落ちても投稿は通す。
    def fill_cold_cache
      return if sources.none?
      requested = request_refresh
      @cache = nil
      return if cache.is_a?(Hash)
      restore_from_sources(log: requested)
    rescue => e
      e.log
      @cache ||= {}
    end

    # 更新の依頼。出せたとき true。
    #
    # ⚠ **印（`REFRESH_REQUEST_KEY`）を取れた 1 本だけが出す。**Sidekiq が止まっている間も
    # 投稿は届くので、印が無いと投稿の数だけジョブが積まれる。
    # ⚠ 積まれたジョブは `'cold' => true` で、**走る時点で本体キャッシュが埋まっていれば
    # 何もしない**（`TaggingDictionaryUpdateWorker#perform`）。Sidekiq が長く止まった後に、
    # 溜まった依頼がまとめて GAS を叩かないため。
    def request_refresh
      ttl = TaggingDictionary::REFRESH_REQUEST_TTL
      return false unless redis.acquire(TaggingDictionary::REFRESH_REQUEST_KEY, ttl)
      TaggingDictionaryUpdateWorker.perform_async('cold' => true)
      return true
    rescue => e
      e.log
      return false
    end

    # ⚠ **ログは依頼を出せた回だけ**（＝ `REFRESH_REQUEST_TTL` に 1 行）。本体キャッシュが
    # 無い間は投稿のたびにここを通るので、毎回出すと syslog が埋まる（#4549 の型）。
    def restore_from_sources(log:)
      @substituted_sources = Concurrent::Array.new
      dics = remote_dictionaries
      entries = merge(dics.map {|dic| restore_source(dic)})
      @cache = entries
      return unless log
      logger.error(
        message: 'tagging dictionary cold',
        redis_key: TaggingDictionary::REDIS_KEY,
        signature:,
        sources: sources.size,
        restored_sources: @substituted_sources.to_a.size,
        entries: entries.size,
      )
    end

    # 据え置いた回に、本体キャッシュの寿命を延ばす (#4628 の 9 件目)。延ばせたとき true。
    #
    # ⚠⚠ 延ばさないと、**1 本のソースが 1 時間落ち続けただけで本体が失効し**、次の回に
    # 「生きたキャッシュが無い」扱いで痩せた辞書が公開される（据え置きが 1 時間しか持たない）。
    # ⚠ **無期限には延ばさない。**作ってから `source_ttl`（last-good と同じ 24 時間）まで。
    def extend_cache_ttl
      return false unless generated_at
      # ⚠ **延ばす先も上限で切る（PR #4830 の Codex P2）。**上限の直前の回が `cache_ttl` を
      # 丸ごと置くと、23 時間 50 分めの据え置きで 24 時間 50 分まで生き延びる。
      remaining = (source_cache_ttl - (Time.now - generated_at)).floor
      return false unless remaining.positive?
      return redis.expire(TaggingDictionary::REDIS_KEY, [cache_ttl, remaining].min)
    rescue => e
      e.log
      return false
    end
  end
end
