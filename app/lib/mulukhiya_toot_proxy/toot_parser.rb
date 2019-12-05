module MulukhiyaTootProxy
  class TootParser
    attr_reader :body

    def initialize(body)
      @body = body
      @config = Config.instance
      @logger = Logger.new
    end

    def reply_to
    end
    
    def hashtags
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
  end
end
