module MulukhiyaTootProxy
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      account = Account.new(id: params['account_id'])
      account&.create_clipper(:growi)&.clip(
        body: create_body(params),
        path: GrowiClipper.create_path(account.username),
      )
    end
  end
end
