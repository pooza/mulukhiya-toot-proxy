module Mulukhiya
  class PiefedClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.piefed?
      return super
    end

    def perform(params = {})
      initialize_params(params)
      unless piefed = account_class[params[:account_id]]&.piefed
        raise Ginseng::ConfigError "Piefed undefined (Account #{params[:account_id]})"
      end
      piefed.clip(url: create_status_uri(params[:uri]))
    end
  end
end
