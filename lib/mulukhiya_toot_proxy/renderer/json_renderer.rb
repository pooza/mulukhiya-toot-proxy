require 'json'

module MulukhiyaTootProxy
  class JsonRenderer < Renderer
    attr_accessor :message

    def to_s
      return @message.to_json
    end
  end
end
