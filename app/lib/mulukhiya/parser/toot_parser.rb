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

    def command?
      return true if params.key?('command')
      return false
    rescue
      return false
    end

    def to_md
      md = text.clone
      ['.u-url', '.hashtag'].each do |selector|
        nokogiri.css(selector).each do |link|
          md.gsub!(link.to_s, "[#{link.inner_text}](#{link.attributes['href'].value})")
        rescue => e
          @logger.error(error: e.message, link: link.to_s)
        end
      end
      return TootParser.sanitize(md)
    end

    def all_tags
      unless @all_tags
        container = TagContainer.new
        container.concat(tags)
        container.concat(@account.tags) if @account
        return @all_tags = container.create_tags
      end
      return @all_tags
    end

    def max_length
      if Environment.pleroma?
        length = @config['/pleroma/status/max_length']
      else
        length = @config['/mastodon/status/max_length']
      end
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end
  end
end
