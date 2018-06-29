require 'json'
require 'mulukhiya/renderer'

module MulukhiyaTootProxy
  class JSONRenderer < Renderer
    attr_accessor :message

    def to_s
      return @message.to_json
    end
  end
end
