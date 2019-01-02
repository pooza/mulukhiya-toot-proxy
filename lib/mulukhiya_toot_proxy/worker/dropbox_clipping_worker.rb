module MulukhiyaTootProxy
  class DropboxClippingWorker
    include Sidekiq::Worker

    def perform(params)
      return unless clipper = DropboxClipper.create({account_id: params['account']['id']})
      clipper.clip({body: params['body']})
    end
  end
end
