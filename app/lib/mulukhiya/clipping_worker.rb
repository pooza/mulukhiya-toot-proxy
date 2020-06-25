module Mulukhiya
  class ClippingWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
    end

    def underscore_name
      return self.class.to_s.split('::').last.sub(/Worker$/, '').underscore
    end

    def federate?
      return @config["/worker/#{underscore_name}/federate"] == true
    raise Ginseng::ConfigError
      return false
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      uri = TootURI.parse(params['uri'])
      uri = NoteURI.parse(params['uri']) unless uri&.valid?
      raise Ginseng::RequestError, "Invalid URL '#{params['uri']}'" unless uri&.valid?
      if (uri.host == Environment.domain_name) || federate?
        return uri.to_md
      else
        return uri.to_s
      end
    end
  end
end
