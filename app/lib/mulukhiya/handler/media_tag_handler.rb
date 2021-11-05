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

    def self.all
      return {} unless TagContainer.media_tag?
      return [:image, :video, :audio].map {|v| [v, config["/handler/media_tag/tags/#{v}"]]}.to_h
    end

    private

    def media_ids
      return Set.new(payload[attachment_field] || [])
    end

    def create_media_tags(id)
      type = attachment_class[id].type
      media = [:image, :video, :audio].select {|v| type.start_with?("#{v}/")}
      return TagContainer.new([self.class.all[media]])
    end
  end
end
