module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def disable?(handler_name)
      return self["/handler/#{handler_name}/disable"] == true
    rescue Ginseng::ConfigError
      return false
    end
  end
end
