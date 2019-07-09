module MulukhiyaTootProxy
  class DropboxClippingWorker < ClippingWorker
    def perform(params)
      return unless clipper = create_clipper(params['account']['id'])
      clipper.clip(body: create_body(params))
    end
  end
end
