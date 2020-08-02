module Mulukhiya
  module StatusMethods
    def logger
      @logger ||= Logger.new
      return @logger
    end
  end
end
