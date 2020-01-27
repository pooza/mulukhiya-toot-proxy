module Mulukhiya
  class Acct
    attr_reader :contents
    attr_reader :username
    attr_reader :host

    def initialize(contents)
      @contents = contents
      @username, @host = @contents.sub(/^@/, '').split('@')
      @config = Config.instance
    end

    alias to_s contents

    def agent?
      @config['/agent/accts'].member?(contents)
    end

    def valid?
      return @contents.match?(Acct.pattern)
    end

    def self.pattern
      return Environment.parser_class.acct_pattern
    end
  end
end
