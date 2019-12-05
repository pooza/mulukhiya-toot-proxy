module MulukhiyaTootProxy
  class TootParser
    attr_reader :body

    def initialize(body)
      @body = body
      @config = Config.instance
      @logger = Logger.new
    end

    def length
      return body.length
    end

    alias size length

    def too_long?
      return TootParser.max_length < length
    end

    def reply_to
      return body.scan(/@[[::word]]+(@.[[:alnum:]]+)?/).map(&:first)
    end

    def hashtags
      return TagContainer.scan(body)
    end

    alias tags hashtags

    def command?
    end

    def command_name
    end

    alias command command_name

    def command_params
    end

    alias params command_params

    def self.max_length
      length = Config.instance['/mastodon/toot/max_length']
      tags = TagContainer.default_tags
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end
  end
end
