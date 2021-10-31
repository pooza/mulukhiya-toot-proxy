module Mulukhiya
  class DefaultTagHandler < TagHandler
    def addition_tags
      return DefaultTagHandler.tags
    end

    def self.tags
      return TagContainer.new((config['/tagging/default_tags'] rescue []))
    end

    def self.remote_tags
      tags = TagContainer.new
      config['/tagging/remote'].each do |remote|
        tags.merge(remote['tags'])
      end
      return tags
    end
  end
end
