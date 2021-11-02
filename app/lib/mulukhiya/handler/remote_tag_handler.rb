module Mulukhiya
  class RemoteTagHandler < TagHandler
    def addition_tags
      text = TaggingDictionary.new.create_temp_text(payload)
      tags = TagContainer.new
      self.class.entries.select {|v| text.match?(v['pattern'])}.each do |remote|
        tags.merge(remote['tags'])
        service = Ginseng::Fediverse::MulukhiyaService.new(remote['url'])
        tags.merge(service.search_hashtags(text))
      rescue => e
        logger.error(error: e, remote: remote)
      end
      return tags
    end

    def self.entries(&block)
      return enum_for(__method__) unless block
      config['/tagging/remote'].each(&block)
    end
  end
end
