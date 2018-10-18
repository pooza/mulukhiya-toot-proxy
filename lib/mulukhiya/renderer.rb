require 'mulukhiya/config'
require 'mulukhiya/logger'
require 'mulukhiya/error/imprement'

module MulukhiyaTootProxy
  class Renderer
    attr_accessor :status

    def initialize
      @status = 200
      @config = Config.instance
      @logger = Logger.new
    end

    def type
      return 'application/json; charset=UTF-8'
    end

    def to_s
      raise ImprementError, 'to_sが未定義です。'
    end
  end
end
