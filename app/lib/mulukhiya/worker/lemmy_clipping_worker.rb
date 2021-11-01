module Mulukhiya
  class LemmyClippingWorker < ClippingWorker
    def perform(params = {})
      params.deep_stringify_keys!
      return unless controller_class.lemmy?
      return unless account = account_class[params[:account_id]]
      return unless account.lemmy
      return unless uri = create_status_uri(params[:uri])
      return unless uri.valid?
      return unless uri.public?
      account.lemmy.clip(url: uri.to_s)
    end
  end
end
