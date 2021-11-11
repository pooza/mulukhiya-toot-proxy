module Mulukhiya
  class DropboxClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.dropbox?
      return false
    end

    def perform(params = {})
      params.deep_symbolize_keys!
      unless dropbox = account_class[params[:account_id]]&.dropbox
        raise Ginseng::ConfigError "Dropbox undefined (Account #{params[:account_id]})"
      end
      dropbox.clip(body: create_body(params))
    end
  end
end
