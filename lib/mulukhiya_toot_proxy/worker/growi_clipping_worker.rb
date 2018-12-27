module MulukhiyaTootProxy
  class GrowiClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return unless growi = Growi.create({account_id: params['account']['id']})
      growi.clip(uri.to_md)
    rescue ExternalServiceError
      growi.clip({
        body: uri.to_md,
        path: Growi.create_path(params['account']['username']),
      })
    end
  end
end
