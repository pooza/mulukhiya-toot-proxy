module MulukhiyaTootProxy
  class GrowiClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return unless growi = Growi.new({
        crowi_url: params['growi']['url'],
        access_token: params['growi']['token'],
      })
      uri.clip({growi: growi})
    rescue RequestError
      uri.clip({growi: growi, path: Growi.create_path(params['account'])})
    end
  end
end
