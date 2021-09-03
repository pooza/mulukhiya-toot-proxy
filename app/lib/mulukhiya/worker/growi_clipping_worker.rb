module Mulukhiya
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      return unless controller_class.growi?
      return unless account = account_class[params['account_id']]
      return unless account.growi
      account.growi.clip(body: create_body(params))
    end
  end
end
