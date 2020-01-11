require 'sanitize'

module MulukhiyaTootProxy
  class StatusParser
    attr_reader :body
    attr_accessor :account

    def initialize(body = '')
      self.body = body
      @config = Config.instance
      @logger = Logger.new
      @account = Environment.test_account
    end

    alias to_s body

    def accts
      return body.scan(StatusParser.acct_pattern).map(&:first)
    end

    def body=(body)
      @body = body.to_s
      @params = nil
    end

    def length
      return body.length
    end

    alias size length

    def too_long?
      return max_length < length
    end

    def exec
      if @params.nil?
        @params = YAML.safe_load(body)
        @params = JSON.parse(body) unless @params&.is_a?(Hash)
        @params = false unless @params&.is_a?(Hash)
      end
      return @params || nil
    rescue Psych::SyntaxError, JSON::ParserError
      return nil
    rescue Psych::Exception, JSON::JSONError => e
      return @logger.error(e)
    end

    alias params exec

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

    def service
      @sns ||= Environment.sns_class.new
      return @sns
    end

    def to_md
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def all_tags
      container = TagContainer.new
      container.concat(tags)
      container.concat(@account.tags) if @account
      container.concat(TagContainer.default_tags)
      return container.create_tags
    end

    def max_length
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def self.sanitize(text)
      text.gsub!(/<br.*?>/, "\n")
      text.gsub!(%r{</p.*?>}, "\n\n")
      text = Sanitize.clean(text)
      return text.strip
    end

    def self.hashtag_pattern
      return Regexp.new(Config.instance['/hashtag/pattern'], Regexp::IGNORECASE)
    end

    def self.acct_pattern
      return Regexp.new(Config.instance['/acct/pattern'], Regexp::IGNORECASE)
    end
  end
end
