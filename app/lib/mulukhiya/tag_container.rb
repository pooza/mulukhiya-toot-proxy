module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    include Package
    attr_reader :account

    def account=(account)
      @account = account
      reject! {|v| @account.disabled_tag_bases.member?(v)}
      concat(@account.user_tag_bases)
    end

    def self.default_tags
      return config['/tagging/default_tags'].map(&:to_hashtag) rescue []
    end

    def self.default_tag_bases
      return config['/tagging/default_tags'].map(&:to_hashtag_base) rescue []
    end

    def self.media_tag?
      return config['/tagging/media/enable'] == true rescue true
    end

    def self.media_tag_bases
      return [] unless media_tag?
      return ['image', 'video', 'audio'].freeze.map do |tag|
        config["/tagging/media/tags/#{tag}"].to_hashtag_base
      end
    rescue
      return []
    end
  end
end
