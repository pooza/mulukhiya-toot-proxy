module Mulukhiya
  class GrowiClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.growi?
      return super
    end

    def perform(params = {})
      params.deep_symbolize_keys!
      unless growi = account_class[params[:account_id]]&.growi
        raise Ginseng::ConfigError "GROWI undefined (Account #{params[:account_id]})"
      end
      growi.clip(body: create_body(params))
    end
  end
end
