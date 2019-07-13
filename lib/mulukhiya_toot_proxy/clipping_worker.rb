module MulukhiyaTootProxy
  class ClippingWorker
    include Sidekiq::Worker

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      return params['uri']['class'].constantize.parse(params['uri']['href']).to_md
    end
  end
end
