module MulukhiyaTootProxy
  class ClippingWorker
    include Sidekiq::Worker

    def initialize
      @logger = Logger.new
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    private

    def clipper_class
      return self.class.to_s.sub(/ClippingWorker$/, 'Clipper').constantize
    end

    def create_clipper(account_id)
      return clipper_class.create({
        account_id: account_id,
      })
    end

    def create_body(params)
      return params['body'] if params['body'].present?
      uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return uri.to_md if uri
      raise Ginseng::RequestError, 'Bad Request'
    end
  end
end
