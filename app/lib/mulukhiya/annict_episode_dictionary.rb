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
      @cache = @storage.get(KEY)
      return @cache['entries'] if fresh?
      entries = build
      @storage.set(KEY, entries)
      return entries
    rescue => e
      raise unless @cache
      @error = e
      e.log(stale: true, age:) unless alert?
      return @cache['entries']
    end

    # 握った失敗を、呼び出し側が鳴らすべきか。
    def alert?
      return false unless @error
      return true unless @error.is_a?(Ginseng::GatewayError)
      return config['/service/annict/dictionary/cache/alert'] < age
    end

    # 返したキャッシュの古さ（秒）。キャッシュが無ければ nil。
    def age
      return nil unless @cache
      return Time.now.to_i - @cache['updated_at'].to_i
    end

    private

    def fresh?
      return false unless @cache
      return age < config['/service/annict/dictionary/cache/fresh']
    end

    def build
      episodes = @annict.episodes(@annict.works.map {|v| v['annictId'].to_i})
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
