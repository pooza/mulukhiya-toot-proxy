module Mulukhiya
  class ClippingWorker
    include Sidekiq::Worker

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      uri = TootURI.parse(params['uri'])
      uri = NoteURI.parse(params['uri']) unless uri&.valid?
      return uri.to_md if uri&.valid?
    end
  end
end
