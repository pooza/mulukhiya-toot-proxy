module MulukhiyaTootProxy
  class GrowiClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return unless clipper = GrowiClipper.create({account_id: params['account']['id']})
      clipper.clip({
        body: uri.to_md,
        path: GrowiClipper.create_path(params['account']['username']),
      })
    end
  end
end
