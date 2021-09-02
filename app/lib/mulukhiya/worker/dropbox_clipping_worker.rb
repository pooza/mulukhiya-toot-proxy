module Mulukhiya
  class DropboxClippingWorker < ClippingWorker
    sidekiq_options lock: :until_executed, on_conflict: :log

    def perform(params)
      return unless controller_class.dropbox?
      return unless account = account_class[params['account_id']]
      return unless account.dropbox
      account.dropbox.clip(body: create_body(params))
    end
  end
end
