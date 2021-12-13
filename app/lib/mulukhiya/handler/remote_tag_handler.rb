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
        e.log(remote: remote)
      end
      return tags
    end

    def all(&block)
      return enum_for(__method__) unless block
      handler_config(:services).map(&:deep_symbolize_keys).each(&block)
    end

    def self.tags
      return TagContainer.new(Handler.create('remote_tag').all.map {|v| v[:tags]}.flatten)
    end
  end
end
