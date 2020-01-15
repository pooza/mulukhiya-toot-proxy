require 'nokogiri'

module Mulukhiya
  class TootParser < StatusParser
    def accts
      return body.scan(TootParser.acct_pattern).map(&:first)
    end

    def to_md
      html = Nokogiri::HTML.parse(body, nil, 'utf-8')
      tmp_body = body.clone
      ['.u-url', '.hashtag'].each do |style_class|
        html.css(style_class).each do |link|
          tmp_body.gsub!(link.to_s, "[#{link.inner_text}](#{link.attributes['href'].value})")
        rescue => e
          @logger.error(e)
        end
      end
      return StatusParser.sanitize(tmp_body)
    end

    def max_length
      length = Config.instance['/mastodon/toot/max_length']
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
