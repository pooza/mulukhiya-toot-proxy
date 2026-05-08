module Mulukhiya
  class MediaCatalogUpdateWorker < Worker
    sidekiq_options retry: false, queue: 'media_catalog'

    def disable?
      return true unless controller_class.media_catalog?
      return super
    end

    def perform(params = {})
      storage = MediaCatalogStorage.new
      pages = worker_config(:pages) || 3
      [0, 1].each do |only_person|
        cursor = nil
        pages.times do |i|
          page = i + 1
          result = attachment_class.catalog(page:, only_person:, cursor:, skip_cache: true)
          key = "page:#{page}:person:#{only_person}"
          storage.set(key, result)
          log(page:, only_person:, items: result[:items].size)
          break unless result[:has_next]
          cursor = result[:next_cursor] if cursor_paging?
        end
      end
    end

    # Misskey の media_catalog SQL は note_id ベースで unnest を展開するため、
    # 単一ノートに複数添付があると同 note_id の行が連続して並ぶ。non-unique な
    # 並びに対して `note_id < cursor` で次ページを取ると、ページ境界に該当した
    # ノートの残り添付がキャッシュから抜ける (#4325)。短期対処として Misskey
    # では cursor を更新せず OFFSET ページングのみを使う。SQL 側で複合キー
    # cursor へ移行するのは将来の改善 (#4323 と合わせて検討)。
    def cursor_paging?
      return !Environment.misskey_type?
    end
  end
end
