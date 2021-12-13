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

    def all(&block)
      return enum_for(__method__) unless block
      return if disable?
      return [:image, :video, :audio].to_h {|k| [k, handler_config("tags/#{k}")]}.each(&block)
    end

    private

    def media_ids
      return Set.new(payload[attachment_field] || [])
    end

    def create_media_tag(id)
      type = attachment_class[id].type
      media = [:image, :video, :audio].find {|v| type.start_with?("#{v}/")}
      return all[media]
    end
  end
end
