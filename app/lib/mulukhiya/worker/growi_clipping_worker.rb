module Mulukhiya
  class GrowiClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.growi?
      return false
    end

    def perform(params = {})
      return unless account = account_class[params[:account_id]]
      return unless account.growi
      account.growi.clip(body: create_body(params))
    end
  end
end
