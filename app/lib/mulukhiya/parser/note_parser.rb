module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    include SNSMethods

    def default_service
      service = sns_class.new if Environment.misskey_type?
      service ||= MisskeyService.new
      return service
    end

    def accts(&block)
      return enum_for(__method__) unless block
      text.scan(NoteParser.acct_pattern).map(&:first).map {|v| Acct.new(v)}.each(&block)
    end

    def uris(&block)
      return enum_for(__method__) unless block
      # MFM対応として、スペースだけでなく、閉じ括弧もURLの終端と見なす。
      return text.scan(%r{https?://[^())[:space:]]+}) do |link|
        yield URI.parse(link.gsub(/[[:cntrl:]]/, ''))
      end
    end

    alias tags hashtags

    def to_sanitized
      return NoteParser.sanitize(text.dup)
    end

    def default_max_length
      length = service.max_post_text_length
      length -= [:default_tag, :user_tag]
        .filter_map {|name| Handler.create(name)}
        .reject(&:disable?)
        .inject(Set[]) {|tags, h| tags.merge(h.addition_tags)}
        .sum {|v| v.to_hashtag.length + 1}
      length -= 1 # 1行アキはMastodon 4.2対応
      return length
    rescue => e
      e.log(text:)
      return service.max_post_text_length
    end
  end
end
