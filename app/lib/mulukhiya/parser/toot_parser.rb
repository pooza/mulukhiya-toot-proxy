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

    def to_md
      md = text.clone
      ['.u-url', '.hashtag'].each do |style_class|
        nokogiri.css(style_class).each do |link|
          md.gsub!(link.to_s, "[#{link.inner_text}](#{link.attributes['href'].value})")
        rescue => e
          @logger.error(Ginseng::Error.create(e).to_h.merge(link: link.to_s))
        end
      end
      return TootParser.sanitize(md)
    end

    def all_tags
      unless @all_tags
        container = TagContainer.new
        container.concat(tags)
        container.concat(TagContainer.default_tags)
        container.concat(@account.tags) if @account
        return @all_tags = container.create_tags
      end
      return @all_tags
    end

    def max_length
      length = super
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end
  end
end
