module Mulukhiya
  class MediaTagHandler < TagHandler
    def addition_tags
      unless @media_tags
        @media_tags = TagContainer.new
        @media_tags.merge(media_ids.map {|id| create_media_tags(id)})
      end
      return @media_tags
    end

    def payload=(payload)
      super
      @media_tags = nil
    end

    def self.all_tags
      tags = TagContainer.new
      return tags unless TagContainer.media_tag?
      tags.merge([:image, :video, :audio].freeze.map {|v| config["/handler/media_tag/tags/#{v}"]})
      return tags
    rescue
      return TagContainer.new
    end

    private

    def media_ids
      return Set.new(payload[attachment_field] || [])
    end

    def create_media_tags(id)
      type = attachment_class[id].type
      mediatype = [:video, :image, :audio].freeze.select {|v| type.start_with?("#{v}/")}
      return TagContainer.new([config["/handler/media_tag/tags/#{mediatype}"]])
    end
  end
end
