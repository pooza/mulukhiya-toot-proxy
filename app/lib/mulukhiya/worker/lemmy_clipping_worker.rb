module Mulukhiya
  class LemmyClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.lemmy?
      return false
    end

    def perform(params = {})
      params.deep_symbolize_keys!
      return unless account = account_class[params[:account_id]]
      return unless account.lemmy
      return unless uri = create_status_uri(params[:uri])
      return unless uri.valid?
      return unless uri.public?
      account.lemmy.clip(url: uri.to_s)
    end
  end
end
