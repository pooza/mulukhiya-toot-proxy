module Mulukhiya
  class RemoteTagHandler < TagHandler
    def addition_tags
      text = flatten_payload
      dic = TaggingDictionary.new
      tags = TagContainer.new
      all.select {|v| text.match?(v[:pattern])}.each do |remote|
        tags.merge(remote[:tags])
        service = Ginseng::Fediverse::MulukhiyaService.new(remote[:url])
        next if sns.uri.host == service.base_uri.host
        tags.merge(service.search_hashtags(text).reject {|v| dic.short?(v)})
      rescue => e
        e.log(remote:)
      end
      return tags
    end

    def all(&block)
      return enum_for(__method__) unless block
      handler_config(:services).map(&:deep_symbolize_keys).each(&block)
    end

    def self.tags
      return TagContainer.new(new.all.map {|v| v[:tags]}.flatten)
    rescue => e
      e.log
      return TagContainer.new
    end
  end
end
