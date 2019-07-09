module MulukhiyaTootProxy
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      return unless clipper = create_clipper(params['account']['id'])
      clipper.clip(
        body: create_body(params),
        path: GrowiClipper.create_path(params['account']['username']),
      )
    end
  end
end
