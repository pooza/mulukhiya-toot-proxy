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
  # ⚠ **キーワード（`/service/annict/works`）を入れ替えた後の空も、正しい答えとして書く**（PR #4834 の Codex P2）。
  # 新しい作品に題のついた回がまだ無いと、前の作品の回が寿命まで残るため。キャッシュにキーワードを添えて見分ける。
  # ⚠ 見分けるのは設定のキーワードで、Annict が返した作品の ID ではない。不調のときは作品の検索も欠けるので、
  # ID で比べると「凌ぐための結果」を障害の最中に捨てる。アカウントの視聴中の作品（`viewers_works?`）の
  # 入れ替わりは見分けない。
  # ⚠⚠ **アラートは 1 回の障害につき `alert` 秒に 1 回。**辞書は 10 分おきに引かれるので、
  # 古さだけで判定すると 6 時間を超えた障害では取得のたびに鳴る（#4801 で消したかった状態に戻る）。
  class AnnictEpisodeDictionary
    include Package

    KEY = 'episodes'.freeze

    # 鍵として認める最短の長さ (#4865)。
    MIN_KEY_LENGTH = 16

    attr_reader :error

    # 辞書の口（`GET /tagging/dic/annict/episodes`）の鍵か (#4865)。
    # ⚠ 鍵が 1 つも無ければ、誰も通さない。
    # ⚠ **短い鍵は設定にあっても無視する**（PR #4867 の Codex P2）。スキーマの検査（#4869）は
    # `strict` が false の間は起動を止めないので、ここでも落とす。
    def self.key?(key)
      return key_rejection(key).nil?
    end

    # 鍵を断る理由。通すなら nil。
    #
    # ⚠ **理由はログで区別するためのもの**（5.44.0 のリリース前レビューの黄）。姉妹サーバーが
    # 鍵を設定するとき、取りに来る側には `Bad response 403` しか残らないので、配る側のログで
    # 原因を読む。⚠ 応答の本文には出さない（`Unauthorized` のまま）。鍵そのものも残さない。
    def self.key_rejection(key)
      return :missing unless key.is_a?(String) && key.present?
      keys = Array(Config.instance['/service/annict/dictionary/keys']).grep(String)
      return :not_configured unless keys.any?(&:present?)
      keys = keys.select {|v| MIN_KEY_LENGTH <= v.length}
      return :too_short unless keys.present?
      return nil if keys.any? {|v| Rack::Utils.secure_compare(v, key)}
      return :mismatch
    end

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
      return keep_cache if entries.empty? && @works.present? && cached_entries? && same_keywords?
      @storage.set(KEY, entries, keywords:)
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

    def keywords
      # ⚠ 設定が配列でなく 1 語で書かれていても落とさない（5.42.0 のリリース前レビュー）。
      return Array(AnnictService.keywords).map(&:to_s).sort
    end

    # ⚠ キーワードを持たない古い形のキャッシュ（5.41.0 まで）は、同じものとして扱う（守る側へ倒す）。
    def same_keywords?
      return true unless @cache['keywords'].is_a?(Array)
      return @cache['keywords'] == keywords
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
