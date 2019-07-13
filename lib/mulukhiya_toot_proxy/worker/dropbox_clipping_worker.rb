module MulukhiyaTootProxy
  class DropboxClippingWorker < ClippingWorker
    def perform(params)
      account = Account.new(id: params['account_id'])
      account&.create_clipper(:dropbox)&.clip(body: create_body(params))
    end
  end
end
