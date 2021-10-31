module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    include Package
    attr_reader :account

    def member?(item)
      return super(item.to_hashtag_base)
    end

    def account=(account)
      @account = account
      reject! {|v| @account.disabled_tags.member?(v)}
      merge(@account.user_tags)
    end

    def self.scan(text)
      return TagContainer.new(
        text.scan(Ginseng::Fediverse::Parser.hashtag_pattern).map(&:first),
      )
    end

    def self.default_tags
      return TagContainer.new((config['/tagging/default_tags'] rescue []))
    end

    def self.remote_default_tags
      tags = TagContainer.new
      config['/tagging/remote'].each do |remote|
        tags.merge(remote['tags'])
      end
      return tags
    end

    def self.media_tag?
      return Handler.create('media_tag').disable? == false
    end

    def self.media_tags
      tags = TagContainer.new
      return tags unless media_tag?
      tags.merge(['image', 'video', 'audio'].freeze.map {|v| config["/tagging/media/tags/#{v}"]})
      return tags
    rescue
      return TagContainer.new
    end
  end
end
