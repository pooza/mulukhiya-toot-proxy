module Mulukhiya
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.growi
      account.growi.clip(
        body: create_body(params),
        path: GrowiClipper.create_path(account.username),
      )
    end
  end
end
