require 'nokogiri'

module Mulukhiya
  class TootParser < StatusParser
    def accts
      return enum_for(__method__) unless block_given?
      text.scan(TootParser.acct_pattern).map(&:first).each do |acct|
        yield Acct.new(acct)
      end
    end

    def to_md
      html = Nokogiri::HTML.parse(text, nil, 'utf-8')
      md = text.clone
      ['.u-url', '.hashtag'].each do |style_class|
        html.css(style_class).each do |link|
          md.gsub!(link.to_s, "[#{link.inner_text}](#{link.attributes['href'].value})")
        rescue => e
          @logger.error(Ginseng::Error.create(e).to_h.merge(link: link.to_s))
        end
      end
      return StatusParser.sanitize(md)
    end

    def max_length
      length = @config['/mastodon/toot/max_length']
      length = length - all_tags.join(' ').length - 1 if create_tags.present?
      return length
    end

    def self.hashtag_pattern
      return Regexp.new(Config.instance['/mastodon/hashtag/pattern'], Regexp::IGNORECASE)
    end

    def self.acct_pattern
      return Regexp.new(Config.instance['/mastodon/acct/pattern'], Regexp::IGNORECASE)
    end
  end
end
