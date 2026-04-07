module Mulukhiya
  class MediaCatalogUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.media_catalog?
      return super
    end

    def perform(params = {})
      storage = MediaCatalogStorage.new
      pages = worker_config(:pages) || 3
      [0, 1].each do |only_person|
        pages.times do |i|
          page = i + 1
          result = attachment_class.catalog(page:, only_person:, skip_cache: true)
          key = "page:#{page}:person:#{only_person}"
          storage.set(key, result)
          log(page:, only_person:, items: result[:items].size)
          break unless result[:has_next]
        end
      end
    end
  end
end
