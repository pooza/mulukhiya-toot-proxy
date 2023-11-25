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

    def to_mfm
      temp = text.dup
      matches = text.scan(/\[.*?\]\(.*?\)/)
      matches.each_with_index do |match, i|
        temp.replace!(match, "____#{i}____")
      end
      self.class.new(temp).uris.select {|v| v.start_with?('http')}.each do |uri|
        temp = "[#{uri.host}](#{uri})"
      end
      matches.each_with_index do |match, i|
        temp.replace!("____#{i}____", match)
      end
      return temp
    end
  end
end
