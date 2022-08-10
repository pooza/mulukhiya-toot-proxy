module Mulukhiya
  class LemmyClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.lemmy?
      return super
    end

    def perform(params = {})
      initialize_params(params)
      unless lemmy = account_class[params[:account_id]]&.lemmy
        raise Ginseng::ConfigError "Lemmy undefined (Account #{params[:account_id]})"
      end
      lemmy.clip(url: create_status_uri(params[:uri]))
    end
  end
end
