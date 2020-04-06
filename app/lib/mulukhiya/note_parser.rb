module Mulukhiya
  class NoteParser < StatusParser
    ATMARK = '__ATMARK__'.freeze
    HASH = '__HASH__'.freeze
    attr_accessor :dolphin
    attr_accessor :account

    def initialize(text = '')
      super(text)
      if Environment.dolphin?
        @service = DolphinService.new
      else
        @service = MisskeyService.new
      end
    end

    def accts
      return enum_for(__method__) unless block_given?
      text.scan(NoteParser.acct_pattern).map(&:first).each do |acct|
        yield Acct.new(acct)
      end
    end

    def to_md
      md = text.clone
      tags.sort_by(&:length).reverse_each do |tag|
        md.gsub!("\##{tag}", "[#{HASH}#{tag}](#{@service.create_uri("/tags/#{tag}")})")
      end
      accts.sort_by {|v| v.scan(/@/).count * 100_000_000 + v.length}.reverse_each do |acct|
        md.sub!(acct, "[#{acct.gsub('@', ATMARK)}](#{@service.create_uri("/#{acct}")})")
      end
      md.gsub!(HASH, '#')
      md.gsub!(ATMARK, '@')
      return StatusParser.sanitize(md)
    end

    def max_length
      length = @config['/dolphin/note/max_length']
      length = length - all_tags.join(' ').length - 1 if create_tags.present?
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
