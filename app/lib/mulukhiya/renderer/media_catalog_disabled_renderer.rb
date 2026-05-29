module Mulukhiya
  class MediaCatalogDisabledRenderer
    STATUS = 503
    EMPTY_PAYLOAD = {available: false, items: [].freeze, has_next: false}.freeze

    def self.apply!(renderer, endpoint:)
      Logger.new.info(media_catalog: {event: 'disabled_response', endpoint:})
      renderer.status = STATUS
      renderer.message = EMPTY_PAYLOAD if renderer.is_a?(Ginseng::Web::JSONRenderer)
      return renderer
    end
  end
end
