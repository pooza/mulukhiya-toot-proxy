module MulukhiyaTootProxy
  class ClippingWorker
    include Sidekiq::Worker

    def perform(params)
      raise ImplementError, "'#{__method__}' not implemented"
    end

    private

    def create_clipper(account_id)
      return self.class.to_s.sub(/ClippingWorker$/, 'Clipper').constantize.create({
        account_id: account_id,
      })
    end

    def create_body(params)
      return params['body'] if params['body'].present?
      uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return uri.to_md if uri
      raise RequestError, 'Bad Request'
    end
  end
end
