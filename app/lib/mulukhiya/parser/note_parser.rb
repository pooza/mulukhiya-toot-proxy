module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    attr_accessor :account, :service

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

    def max_length
      length = config['/misskey/status/max_length'] unless Environment.misskey_type?
      length ||= config["/#{Environment.controller_name}/status/max_length"]
      length -= (all_tags.create_tags.join(' ').length + 1) if all_tags.present?
      return length
    end
  end
end
