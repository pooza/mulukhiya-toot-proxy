module MulukhiyaTootProxy
  class GrowiClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return unless growi = Growi.create({account_id: params['account']})
      uri.clip({growi: growi})
    rescue RequestError
      uri.clip({growi: growi, path: Growi.create_path(params['account'])})
    end
  end
end
