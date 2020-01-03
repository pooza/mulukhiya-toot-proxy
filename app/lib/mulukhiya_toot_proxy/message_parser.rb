require 'sanitize'

module MulukhiyaTootProxy
  class MessageParser
    attr_reader :body

    def initialize(body = '')
      self.body = body
      @config = Config.instance
      @logger = Logger.new
    end

    alias to_s body

    def body=(body)
      @body = body.to_s
      @params = nil
    end

    def length
      return body.length
    end

    alias size length

    def too_long?
      return false
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
      return MessageParser.sanitize(body)
    end

    def self.sanitize(text)
      text.gsub!(/<br.*?>/, "\n")
      text.gsub!(%r{</p.*?>}, "\n\n")
      text = Sanitize.clean(text)
      return text.strip
    end
  end
end
