module Mulukhiya
  class RemoteTagHandler < TagHandler
    def disable?
      return false
    end

    def addition_tags
      text = flatten_payload
      dic = TaggingDictionary.new
      local_tags = dic.matches(text)
      tags = Concurrent::Array.new
      Parallel.each(all, in_threads: Parallel.processor_count) do |remote|
        next unless text.match?(remote[:pattern])
        tags.concat(remote[:tags])
        service = Ginseng::Fediverse::MulukhiyaService.new(remote[:url])
        next if sns.uri.host == service.base_uri.host
        remote_tags = service.search_hashtags(text)
        tags.concat(remote_tags.reject {|v| dic.short?(v) || local_tags.member?(v)})
      rescue => e
        e.log(remote:)
      end
      return TagContainer.new(tags.uniq)
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
