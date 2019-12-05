module MulukhiyaTootProxy
  class TootParser
    attr_reader :body

    def initialize(body)
      @body = body
      @config = Config.instance
      @logger = Logger.new
    end

    alias to_s body

    def length
      return body.length
    end

    alias size length

    def too_long?
      return TootParser.max_length < length
    end

    def exec
      @params ||= (YAML.safe_load(body) || JSON.parse(body))
      return nil unless @params&.is_a?(Hash)
      return @params
    rescue Psych::SyntaxError, JSON::ParserError
      return nil
    rescue Psych::Exception, JSON::JSONError => e
      return @logger.error(e)
    end

    alias params exec

    def reply_to
      return body.scan(/@[[::word]]+(@.[[:alnum:]]+)?/).map(&:first)
    end

    def hashtags
      return TagContainer.scan(body)
    end

    alias tags hashtags

    def command?
      return command_name.present?
    end

    def command_name
      return params['command']
    rescue
      return nil
    end

    alias command command_name

    def self.max_length
      length = Config.instance['/mastodon/toot/max_length']
      tags = TagContainer.default_tags
      length = length - tags.join(' ').length - 1 if tags.present?
      return length
    end
  end
end
