module Mulukhiya
  class MediaCatalogUpdateWorker < Worker
    def perform(params = {})
      params.deep_symbolize_keys!
      params[:page] ||= 1
      params[:limit] ||= config['/feed/media/limit']
      storage.clear
      attachment_class.catalog(params)
      logger.info(class: self.class.to_s, page: params[:page])
    end

    private

    def storage
      @storage ||= MediaCatalogRenderStorage.new
      return @storage
    end
  end
end
