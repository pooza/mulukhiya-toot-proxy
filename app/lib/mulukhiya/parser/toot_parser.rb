module Mulukhiya
  class TootParser < Ginseng::Fediverse::TootParser
    include Package
    include SNSMethods
    attr_accessor :account

    def accts(&block)
      return enum_for(__method__) unless block
      text.scan(TootParser.acct_pattern).map(&:first).map {|v| Acct.new(v)}.each(&block)
    end

    def to_sanitized
      return TootParser.sanitize(text.dup)
    end

    def hashtags
      return TagContainer.scan(text)
    end

    alias tags hashtags

    def all_tags
      tags = hashtags.clone
      tags.merge(DefaultTagHandler.tags)
      tags.merge(@account.user_tags) if @account
      return tags
    end

    def default_max_length
      length = service.max_post_text_length
      length -= (all_tags.create_tags.join(' ').length + 5) if all_tags.present?
      return length
    rescue => e
      e.log(text:)
      return config['/mastodon/status/default_max_length']
    end

    def service
      return Environment.mastodon_type? ? sns_class.new : MastodonService.new
    end
  end
end
