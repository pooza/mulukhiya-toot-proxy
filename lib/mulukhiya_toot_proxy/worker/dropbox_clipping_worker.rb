module MulukhiyaTootProxy
  class DropboxClippingWorker < ClippingWorker
    def perform(params)
      account = Account.new(id: params['account_id'])
      clipper_class.create(account_id: account.id)&.clip(
        body: create_body(params),
      )
    end
  end
end
