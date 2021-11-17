module Mulukhiya
  class MediaCatalogUpdateWorker < Worker
    def perform(params = {})
      params.deep_symbolize_keys!
      params[:page] ||= 1
      params[:limit] ||= config['/feed/media/limit']
      MediaCatalogRenderStorage.new.clear
      attachment_class.catalog(params)
    end
  end
end
