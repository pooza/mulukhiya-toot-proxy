module MulukhiyaTootProxy
  class NoteParser < MessageParser
    attr_accessor :dolphin

    def initialize(body = '')
      super(body)
      @dolphin = DolphinService.new
    end

    def too_long?(account = Environment.test_account)
      return NoteParser.max_length(account) < length
    end

    def accts
      return body.scan(NoteParser.acct_pattern).map(&:first)
    end

    def to_md
      tmp_body = body.clone
      tags.sort_by(&:length).reverse_each do |tag|
        uri = @dolphin.uri.clone
        uri.path = "/tags/#{tag}"
        tmp_body.gsub!("\##{tag}", "[__HASH__#{tag}](#{uri})")
      end
      accts.sort_by {|v| v.scan(/@/).count * 100_000_000 + v.length}.reverse_each do |acct|
        uri = @dolphin.uri.clone
        uri.path = "/#{acct}"
        tmp_body.sub!(acct, "[#{acct.gsub('@', '__ATMARK__')}](#{uri})")
      end
      tmp_body.gsub!('__HASH__', '#')
      tmp_body.gsub!('__ATMARK__', '@')
      return MessageParser.sanitize(tmp_body)
    end

    def self.max_length(account = Environment.test_account)
      length = Config.instance['/dolphin/note/max_length']
      tags = TagContainer.default_tags
      tags.concat(account.tags) if account
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end

    def self.hashtag_pattern
      return Regexp.new(Config.instance['/dolphin/hashtag/pattern'], Regexp::IGNORECASE)
    end

    def self.acct_pattern
      return Regexp.new(Config.instance['/dolphin/acct/pattern'], Regexp::IGNORECASE)
    end
  end
end
