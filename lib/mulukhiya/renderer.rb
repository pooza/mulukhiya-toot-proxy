require 'mulukhiya/config'

module MulukhiyaTootProxy
  class Renderer
    attr_accessor :status

    def initialize
      @status = 200
      @config = Config.instance
    end

    def type
      return 'application/json; charset=UTF-8'
    end

    def to_s
      raise 'to_sが未定義です。'
    end
  end
end
