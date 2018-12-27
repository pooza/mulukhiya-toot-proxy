module MulukhiyaTootProxy
  class GrowiClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return unless growi = GrowiClipper.create({account_id: params['account']['id']})
      growi.clip(uri.to_md)
    rescue ExternalServiceError
      growi.clip({
        body: uri.to_md,
        path: GrowiClipper.create_path(params['account']['username']),
      })
    end
  end
end
