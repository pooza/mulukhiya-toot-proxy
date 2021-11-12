module Mulukhiya
  class LemmyClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.lemmy?
      return false
    end

    def perform(params = {})
      params.deep_symbolize_keys!
      unless lemmy = account_class[params[:account_id]]&.lemmy
        raise Ginseng::ConfigError "Lemmy undefined (Account #{params[:account_id]})"
      end
      lemmy.clip(url: create_status_uri(params[:uri]))
    end
  end
end
