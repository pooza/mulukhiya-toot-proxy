module Mulukhiya
  # お知らせボットが見ている作品のエピソードを、タグ辞書の形にする (#4801)。
  #
  # 🔴 **Annict の不調をそのまま 502 とアラートにしない。**以前は要求のたびに GraphQL を
  # 2 回（`works` → `episodes`・各 5 秒でタイムアウト）同期で投げ、失敗は毎回アラートになった。
  # 2026-10-04 から Annict の応答が遅くなり、本番 2 台で 1 日 150 件前後のアラート
  # （Sentry ＋メール）が出て、ほかのアラートが埋もれた。辞書を引く側は取得に失敗した回の
  # ソースを丸ごと欠く。
  #
  # - **直近の成功結果を持ち、失敗したらそれを返す**（エピソードの一覧は分単位では変わらない）
  # - **新しいうちは Annict を引かない**（`fresh` 秒。辞書は各サーバーが 10 分おきに引きに来る）
  # - **アラートは「古い結果で凌げなくなってきた」ときだけ**（`alert` 秒より古い）。
  #   それまでは syslog 止め。⚠ 返せるキャッシュが無いときは従来どおり例外を上げる
  #
  # ⚠ **上流の失敗（`Ginseng::GatewayError`）以外は、凌げていても鳴らす。**こちらのバグを
  # キャッシュの陰に隠さないため。
  #
  # 以下は 5.40.0 のリリース前レビューから。
  # ⚠⚠ **空の結果で、中身のあるキャッシュを上書きしない。**Annict は不調のとき 200 で空の検索結果や
  # `errors` だけを返すことがあり、`AnnictService#episodes` はそれを `[]` として返す。そのまま書くと
  # 「凌ぐための結果」が空になり、続く障害の間ずっと空の辞書を返す。
  # ⚠ キャッシュが無い・もともと空なら、空もそのまま書く。
  # ⚠ **見る作品が 0 件のときの空は、正しい答えとして書く**（PR #4819 の Codex P2）。キーワードを外した
  # 設定変更が、キャッシュの寿命（7 日）まで効かなくなるため。守るのは「作品はあるのに回が空」のときだけ。
  # ⚠⚠ **アラートは 1 回の障害につき `alert` 秒に 1 回。**辞書は 10 分おきに引かれるので、
  # 古さだけで判定すると 6 時間を超えた障害では取得のたびに鳴る（#4801 で消したかった状態に戻る）。
  class AnnictEpisodeDictionary
    include Package

    KEY = 'episodes'.freeze

    attr_reader :error

    def initialize(annict, storage: AnnictDictionaryStorage.new)
      @annict = annict
      @storage = storage
    end

    def fetch
      @error = nil
      @alert = false
      @cache = @storage.get(KEY)
      return @cache['entries'] if fresh?
      entries = build
      return keep_cache if entries.empty? && @works.present? && cached_entries?
      @storage.set(KEY, entries)
      @storage.clear_alert
      return entries
    rescue => e
      raise unless @cache
      @error = e
      @alert = alert_due?
      e.log(stale: true, age:) unless @alert
      return @cache['entries']
    end

    # 握った失敗を、呼び出し側が鳴らすべきか。
    def alert?
      return @alert == true
    end

    # 返したキャッシュの古さ（秒）。キャッシュが無ければ nil。
    def age
      return nil unless @cache
      return Time.now.to_i - @cache['updated_at'].to_i
    end

    private

    # ⚠ こちらのバグ（上流の失敗以外）は毎回 true。間引きは呼び出し側の `throttled_alert` に任せる。
    # ⚠ 上流の失敗は、古さが `alert` 秒を超えていて、かつこの障害でまだ鳴らしていないときだけ。
    def alert_due?
      return true unless @error.is_a?(Ginseng::GatewayError)
      seconds = config['/service/annict/dictionary/cache/alert']
      return false unless seconds < age
      return @storage.first_alert?(seconds)
    end

    def cached_entries?
      return @cache.present? && @cache['entries'].present?
    end

    def keep_cache
      logger.warn(
        class: self.class.to_s,
        message: 'empty result ignored (cache kept)',
        age:,
        cached: @cache['entries'].size,
      )
      return @cache['entries']
    end

    def fresh?
      return false unless @cache
      return age < config['/service/annict/dictionary/cache/fresh']
    end

    def build
      @works = @annict.works
      episodes = @annict.episodes(@works.map {|v| v['annictId'].to_i})
      return episodes.filter_map do |e|
        title = e['title'].to_s.strip
        next if title.empty?
        if (m = e['numberText'].to_s[/\d+/])
          [title, ["#{m}話"]]
        else
          [title, []]
        end
      end.to_h
    end
  end
end
