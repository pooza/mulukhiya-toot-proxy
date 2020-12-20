module Mulukhiya
  module StatusMethods
    def logger
      @logger ||= Logger.new
      return @logger
    end

    def config
      return Config.instance
    end

    def visible?
      return visibility == 'public'
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def logger
        return Logger.new
      end

      def config
        return Config.instance
      end
    end
  end
end
