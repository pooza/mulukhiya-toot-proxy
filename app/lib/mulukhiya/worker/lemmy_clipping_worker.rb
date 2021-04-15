module Mulukhiya
  class LemmyClippingWorker < ClippingWorker
    sidekiq_options lock: :until_executed

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.lemmy
      return unless uri = Controller.create_status_uri(params['uri'])
      return unless uri.valid?
      return unless uri.public?
      account.lemmy.clip(url: uri.to_s)
    end
  end
end
