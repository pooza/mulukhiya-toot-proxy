module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    attr_accessor :account, :service

    def to_sanitized
      return NoteParser.sanitize(text.dup)
    end

    def accts
      return enum_for(__method__) unless block_given?
      text.scan(NoteParser.acct_pattern).map(&:first).each do |acct|
        yield Acct.new(acct)
      end
    end

    def all_tags
      container = TagContainer.new
      container.concat(tags)
      container.concat(TagContainer.default_tag_bases)
      container.concat(@account.user_tag_bases) if @account
      return container.create_tags
    end

    def max_length
      if Environment.misskey_type?
        length = config["/#{Environment.controller_name}/status/max_length"]
      else
        length = config['/misskey/status/max_length']
      end
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end
  end
end
