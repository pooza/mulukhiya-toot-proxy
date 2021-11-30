module Mulukhiya
  class MediaTagHandler < TagHandler
    def addition_tags
      tags = TagContainer.new
      tags.merge(media_ids.filter_map {|id| create_media_tag(id)})
      return tags
    end

    def payload=(payload)
      super
      @media_tags = nil
    end

    def self.all
      return {} unless TagContainer.media_tag?
      return [:image, :video, :audio].to_h {|v| [v, config["/handler/media_tag/tags/#{v}"]]}
    end

    private

    def media_ids
      return Set.new(payload[attachment_field] || [])
    end

    def create_media_tag(id)
      type = attachment_class[id].type
      media = [:image, :video, :audio].find {|v| type.start_with?("#{v}/")}
      return self.class.all[media]
    end
  end
end
