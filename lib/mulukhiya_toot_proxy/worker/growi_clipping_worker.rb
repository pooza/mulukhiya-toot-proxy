module MulukhiyaTootProxy
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      clipper_class.create(account_id: params['account']['id'])&.clip(
        body: create_body(params),
        path: GrowiClipper.create_path(params['account']['username']),
      )
    end
  end
end
