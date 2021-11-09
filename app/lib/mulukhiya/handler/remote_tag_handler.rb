module Mulukhiya
  class RemoteTagHandler < TagHandler
    def addition_tags
      text = flatten_payload
      tags = TagContainer.new
      self.class.entries.select {|v| text.match?(v[:pattern])}.each do |remote|
        tags.merge(remote[:tags])
        service = Ginseng::Fediverse::MulukhiyaService.new(remote[:url])
        next if sns.uri.host == service.base_uri.host
        tags.merge(service.search_hashtags(text))
      rescue => e
        logger.error(error: e, remote: remote)
      end
      return tags
    end

    def schema
      return super.deep_merge(
        type: 'object',
        properties: {
          services: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                pattern: {type: 'string'},
                tags: {type: 'array', items: {type: 'string'}},
                url: {type: 'string', format: 'uri'},
              },
            },
          },
        },
        required: ['services'],
      )
    end

    def self.entries
      return enum_for(__method__) unless block_given?
      config['/handler/remote_tag/services'].each do |service|
        yield service.deep_symbolize_keys
      end
    end
  end
end
