module Mulukhiya
  class MediaCatalogDisabledRenderer
    STATUS = 503
    EMPTY_PAYLOAD = {available: false, items: [], has_next: false}.freeze

    def self.apply!(renderer, endpoint:)
      Logger.new.info(media_catalog: {event: 'disabled_response', endpoint:})
      renderer.status = STATUS
      renderer.message = EMPTY_PAYLOAD if renderer.is_a?(Ginseng::Web::JSONRenderer)
      renderer
    end
  end
end
