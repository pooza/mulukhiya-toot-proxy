module MulukhiyaTootProxy
  class GrowiClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless clipper = GrowiClipper.create({account_id: params['account']['id']})
      clipper.clip({
        body: create_body(params),
        path: GrowiClipper.create_path(params['account']['username']),
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
