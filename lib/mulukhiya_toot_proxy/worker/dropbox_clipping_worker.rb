module MulukhiyaTootProxy
  class DropboxClippingWorker < ClippingWorker
    def perform(params)
      return unless account = Account.new(id: params['account_id'])
      account.dropbox&.clip(body: create_body(params))
    end
  end
end
