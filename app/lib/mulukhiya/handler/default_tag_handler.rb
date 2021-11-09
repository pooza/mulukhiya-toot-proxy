module Mulukhiya
  class DefaultTagHandler < TagHandler
    def disable?
      return true unless self.class.tags.present?
      return super
    end

    def addition_tags
      return self.class.tags
    end

    def schema
      return super.deep_merge(
        type: 'object',
        properties: {
          tags: {
            type: 'array',
            items: {type: 'string'},
          },
        },
        required: ['tags'],
      )
    end

    def self.tags
      return TagContainer.new((config['/handler/default_tag/tags']))
    end

    def self.remote_tags
      return TagContainer.new(RemoteTagHandler.entries.map {|v| v[:tags]}.flatten)
    end
  end
end
