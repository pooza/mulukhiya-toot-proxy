module Mulukhiya
  class MediaCatalogUpdateWorker < Worker
    def perform(params = {})
      params.deep_symbolize_keys!
      params[:page] ||= 1
      params[:limit] ||= config['/feed/media/limit']
      storage.clear
      storage[params] = catalog(params).map {|row| attachment_class[row[:id]].to_h}
      logger.info(class: self.class.to_s, page: params[:page])
    end

    private

    def catalog(params)
      return Postgres.instance.execute('media_catalog', params)
    end

    def storage
      @storage ||= MediaCatalogRenderStorage.new
      return @storage
    end
  end
end
