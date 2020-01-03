module MulukhiyaTootProxy
  class NoteParser < MessageParser
    attr_accessor :dolphin

    def initialize(body = '')
      super(body)
      @dolphin = DolphinService.new
    end

    def too_long?
      return NoteParser.max_length < length
    end

    def to_md
      tmp_body = body.clone
      tags.sort_by(&:length).reverse_each do |tag|
        uri = @dolphin.uri.clone
        uri.path = "/tags/#{tag}"
        tmp_body.gsub!("\##{tag}", "[__HASH__#{tag}](#{uri})")
      end
      tmp_body.gsub!('__HASH__', '#')
      return MessageParser.sanitize(tmp_body)
    end

    def self.max_length
      length = Config.instance['/dolphin/note/max_length']
      tags = TagContainer.default_tags
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end
  end
end
