module Mulukhiya
  class NextcloudClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.nextcloud?
      return super
    end

    def perform(params = {})
      params.deep_symbolize_keys!
      unless nextcloud = account_class[params[:account_id]]&.nextcloud
        raise Ginseng::ConfigError "Nextcloud undefined (Account #{params[:account_id]})"
      end
      nextcloud.clip(body: create_body(params))
    end
  end
end
