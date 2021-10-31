module Mulukhiya
  class MediaTagHandler < TagHandler
    def addition_tags
      unless @media_tags
        @media_tags = TagContainer.new
        @media_tag.merge((payload[attachment_field] || []).map {|id| create_media_tags(id)})
      end
      return @media_tags
    end

    def create_media_tags(id)
      type = attachment_class[id].type
      return [:video, :image, :audio].freeze.select {|v| type.start_with?("#{v}/")}.map do |media|
        config["/handler/media_tag/tags/#{media}"]
      end.to_set
    end

    def payload=(payload)
      super
      @media_tags = nil
    end

    def self.all_tags
      tags = TagContainer.new
      return tags unless media_tag?
      tags.merge([:image, :video, :audio].freeze.map {|v| config["/tagging/media/tags/#{v}"]})
      return tags
    rescue
      return TagContainer.new
    end
  end
end
