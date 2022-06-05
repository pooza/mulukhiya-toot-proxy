module Mulukhiya
  class TootParser < Ginseng::Fediverse::TootParser
    include Package
    include SNSMethods

    def default_service
      service = sns_class.new if Environment.mastodon_type?
      service ||= MastodonService.new
      return service
    end

    def accts(&block)
      return enum_for(__method__) unless block
      text.scan(TootParser.acct_pattern).map(&:first).map {|v| Acct.new(v)}.each(&block)
    end

    alias tags hashtags

    def to_sanitized
      return TootParser.sanitize(text.dup)
    end

    def default_max_length
      length = service.max_post_text_length
      length -= [:default_tag, :user_tag]
        .filter_map {|name| Handler.create(name)}
        .reject(&:disable?)
        .inject(Set[]) {|tags, h| tags.merge(h.addition_tags)}
        .sum {|v| v.to_hashtag.length + 1}
      return length
    rescue => e
      e.log(text:)
      return service.max_post_text_length
    end
  end
end
