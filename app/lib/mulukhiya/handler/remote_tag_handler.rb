module Mulukhiya
  class RemoteTagHandler < TagHandler
    def addition_tags
      text = flatten_payload
      tags = TagContainer.new
      all.select {|v| text.match?(v[:pattern])}.each do |remote|
        tags.merge(remote[:tags])
        service = Ginseng::Fediverse::MulukhiyaService.new(remote[:url])
        next if sns.uri.host == service.base_uri.host
        tags.merge(service.search_hashtags(text))
      rescue => e
        e.log(remote:)
      end
      return tags
    end

    def all(&)
      return enum_for(__method__) unless block
      handler_config(:services).map(&:deep_symbolize_keys).each(&)
    end

    def self.tags
      tags = TagContainer.new
      if handler = Handler.create('remote_tag')
        tags.merge(handler.all.map {|v| v[:tags]}.flatten)
      end
      return tags
    end
  end
end
