module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    attr_accessor :account

    ATMARK = '__ATMARK__'.freeze
    HASH = '__HASH__'.freeze

    def initialize(text = '')
      super
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
      accts = self.accts.map(&:to_s).sort_by do |acct|
        v = acct.to_s
        v.scan(/@/).count * 100_000_000 + v.length
      end
      accts.reverse_each do |acct|
        md.sub!(acct, "[#{acct.gsub('@', ATMARK)}](#{@service.create_uri("/#{acct}")})")
      end
      md.gsub!(HASH, '#')
      md.gsub!(ATMARK, '@')
      return NoteParser.sanitize(md)
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
      length = @config['/misskey/status/max_length']
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end
  end
end
