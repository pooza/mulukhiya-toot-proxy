module Mulukhiya
  class MediaCatalogUpdateWorker < Worker
    sidekiq_options retry: false, queue: 'media_catalog'

    def disable?
      return true unless controller_class.media_catalog?
      return super
    end

    def perform(params = {})
      # sidekiq-scheduler は Sidekiq::Client.push を直叩きするため Worker.perform_async
      # 側の disable? gate を通らない。media_catalog 無効サーバ (5.23.0 デフォルト) で
      # も schedule (every: 30m) 経由で perform が起動するので、ここでも短絡する (#4343)。
      return if disable?
      storage = MediaCatalogStorage.new
      pages = worker_config(:pages) || 3
      cursor_pagination = attachment_class.cursor_pagination?
      [0, 1].each do |only_person|
        cursor = nil
        pages.times do |i|
          page = i + 1
          result = attachment_class.catalog(page:, only_person:, cursor:, skip_cache: true)
          key = "page:#{page}:person:#{only_person}"
          storage.set(key, result)
          log(page:, only_person:, items: result[:items].size)
          break unless result[:has_next]
          cursor = result[:next_cursor] if cursor_pagination
        end
      end
    end
  end
end
