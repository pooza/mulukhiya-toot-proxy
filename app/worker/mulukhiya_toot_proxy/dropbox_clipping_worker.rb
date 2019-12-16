module MulukhiyaTootProxy
  class DropboxClippingWorker < ClippingWorker
    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.dropbox
      account.dropbox.clip(body: create_body(params))
    end
  end
end
