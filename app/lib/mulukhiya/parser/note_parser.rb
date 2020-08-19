module Mulukhiya
  class NoteParser < Ginseng::Fediverse::NoteParser
    include Package
    attr_accessor :account

    def initialize(text = '')
      super
      if ['misskey', 'meisskey', 'dolphin'].member?(Environment.controller_name)
        @service = Environment.sns_class.new
      else
        @service = MisskeyService.new
      end
    end

    def to_md
      md = text.clone
      tags.sort_by(&:length).reverse_each do |tag|
        md.gsub!("\##{tag}", "[\\#{HASH}#{tag}](#{@service.create_uri("/tags/#{tag}")})")
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
      return Ginseng::Fediverse::Parser.sanitize(md)
    end

    def to_sanitized
      return NoteParser.sanitize(text.clone)
    end

    def accts
      return enum_for(__method__) unless block_given?
      text.scan(NoteParser.acct_pattern).map(&:first).each do |acct|
        yield Acct.new(acct)
      end
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
      if ['misskey', 'meisskey', 'dolphin'].member?(Environment.controller_name)
        length = @config["/#{Environment.controller_name}/status/max_length"]
      else
        length = @config['/misskey/status/max_length']
      end
      length = length - all_tags.join(' ').length - 1 if all_tags.present?
      return length
    end

    def self.visibility_name(name)
      return visibility_names[name.to_sym] if visibility_names.key?(name.to_sym)
      return name if visibility_names.values.member?(name)
      return 'public'
    rescue
      return 'public'
    end

    def self.visibility_names
      return {public: 'public'}.merge(
        [:unlisted, :private, :direct].map do |name|
          [name, Config.instance["/parser/note/visibility/#{name}"]]
        end.to_h,
      )
    end
  end
end
