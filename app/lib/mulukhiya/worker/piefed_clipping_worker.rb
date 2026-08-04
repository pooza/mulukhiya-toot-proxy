module Mulukhiya
  class PiefedClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.piefed?
      return super
    end

    def perform(params = {})
      # schedule は無く enqueue 経路のみだが、perform_async 以外から呼ばれても
      # 成立するよう他の worker と同じ形に揃える (#4506)。
      return if disable?
      initialize_params(params)
      unless piefed = account_class[params[:account_id]]&.piefed
        raise Ginseng::ConfigError "Piefed undefined (Account #{params[:account_id]})"
      end
      piefed.clip(url: create_status_uri(params[:uri]))
      log(account_id: params[:account_id], message: 'clipped')
    end
  end
end
