module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    include SNSMethods

    def to_sanitized
      return NoteParser.sanitize(text.dup)
    end

    def accts(&block)
      return enum_for(__method__) unless block
      text.scan(NoteParser.acct_pattern).map(&:first).map {|v| Acct.new(v)}.each(&block)
    end

    def hashtags
      return TagContainer.scan(text)
    end

    alias tags hashtags

    def default_max_length
      length = service.max_post_text_length
      extra_tags = TagContainer.new
      ['default_tag', 'user_tag']
        .filter_map {|name| Handler.create(name)}
        .reject(&:disable?)
        .each {|h| extra_tags.merge(h.addition_tags)}
      length -= extra_tags.sum {|v| v.to_hashtag.length + 1}
      return length
    rescue => e
      e.log(text:)
      return config['/misskey/status/default_max_length']
    end

    def service
      return Environment.misskey_type? ? sns_class.new : MisskeyService.new
    end
  end
end
