module MulukhiyaTootProxy
  class ClippingWorker
    include Sidekiq::Worker

    def initialize
      @logger = Logger.new
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      return params['uri']['class'].constantize.parse(params['uri']['href']).to_md
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h.merge(params: params))
      raise Ginseng::RequestError, e.message, e.backtrace
    end
  end
end
