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
        raise Ginseng::ConfigError, "Piefed undefined (Account #{params[:account_id]})"
      end
      # ginseng-piefed 0.2.0 から、公開でないトゥートは例外でなく nil で返る (#4750)。
      # 利用者の操作として正常な結果なので、再試行も Sentry もさせず、ログだけ分ける。
      unless piefed.clip(url: create_status_uri(params[:uri]))
        return log(account_id: params[:account_id], message: 'not public', uri: params[:uri].to_s)
      end
      log(account_id: params[:account_id], message: 'clipped')
    end
  end
end
