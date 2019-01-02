module MulukhiyaTootProxy
  class DropboxClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless clipper = DropboxClipper.create({account_id: params['account']['id']})
      clipper.clip({body: create_body(params)})
    end

    def create_body(params)
      return params['body'] if params['body'].present?
      uri = params['uri']['class'].constantize.parse(params['uri']['href'])
      return uri.to_md if uri
      raise RequestError, 'Bad Request'
    end
  end
end
