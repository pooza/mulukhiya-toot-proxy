module MulukhiyaTootProxy
  class DropboxClippingWorker < ClippingWorker
    def perform(params)
      clipper_class.create(account_id: params['account']['id'])&.clip(
        body: create_body(params),
      )
    end
  end
end
