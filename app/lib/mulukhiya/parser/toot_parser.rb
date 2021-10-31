module Mulukhiya
  class TootParser < Ginseng::Fediverse::TootParser
    include Package
    attr_accessor :account

    def accts
      return enum_for(__method__) unless block_given?
      text.scan(TootParser.acct_pattern).map(&:first).each do |acct|
        yield Acct.new(acct)
      end
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

    def max_length
      length = config['/mastodon/status/max_length'] unless Environment.mastodon_type?
      length ||= config["/#{Environment.controller_name}/status/max_length"]
      length -= (all_tags.create_tags.join(' ').length + 1) if all_tags.present?
      return length
    end
  end
end
