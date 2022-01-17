module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    include SNSMethods
    attr_accessor :account

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
      return config['/misskey/status/default_max_length']
    end

    def service
      return Environment.misskey_type? ? sns_class.new : MisskeyService.new
    end
  end
end
