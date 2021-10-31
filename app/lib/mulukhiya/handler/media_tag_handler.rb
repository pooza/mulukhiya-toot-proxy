module Mulukhiya
  class MediaTagHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      tags.text = @status
      tags.merge(media_tags)
      result.push(tags: media_tags)
    end

    private

    def media_tags
      unless @media_tags
        @media_tags = TagContainer.new
        (payload[attachment_field] || []).map {|id| attachment_class[id].type}.each do |type|
          @media_tags.add([:video, :image, :audio].freeze.find {|v| type.start_with?("#{v}/")})
        end
      end
      return @media_tags
    end
  end
end
