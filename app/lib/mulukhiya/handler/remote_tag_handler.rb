module Mulukhiya
  class RemoteTagHandler < TagHandler
    def disable?
      return false
    end

    def addition_tags
      text = flatten_payload
      matched = all.select {|remote| text.match?(remote[:pattern])}
      tags = Concurrent::Array.new
      tags.concat(matched.flat_map {|remote| remote[:tags]})
      # 辞書はリモートから返ってきたタグを絞り込むためだけに使う。照会が 1 件も
      # 起きない投稿（自サーバー宛だけに一致した場合を含む）では作らない (#4482)。
      remotes = matched.reject {|remote| own_service?(remote)}
      tags.concat(search_remote_tags(remotes, text)) if remotes.present?
      return TagContainer.new(tags.uniq)
    end

    def search_remote_tags(remotes, text)
      dic = dictionary
      local_tags = dic.matches(text)
      tags = Concurrent::Array.new
      Parallel.each(remotes, in_threads: Parallel.processor_count) do |remote|
        tags.concat(remote_service(remote).search_hashtags(text).reject do |v|
          dic.short?(v) || local_tags.member?(v) || dic.strict_key?(v)
        end)
      rescue => e
        e.log(remote:)
      end
      return tags
    end

    def remote_service(remote)
      return Ginseng::Fediverse::MulukhiyaService.new(remote[:url])
    end

    def own_service?(remote)
      return sns.uri.host == remote_service(remote).base_uri.host
    rescue => e
      e.log(remote:)
      return false
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
