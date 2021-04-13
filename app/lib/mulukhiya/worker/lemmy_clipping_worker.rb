module Mulukhiya
  class LemmyClippingWorker < ClippingWorker
    sidekiq_options lock: :until_executed

    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.lemmy
      account.lemmy.clip(url: params['uri'])
    end
  end
end
