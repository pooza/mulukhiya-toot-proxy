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
      return true if Environment.test?
      return @config["/worker/#{underscore_name}/federate"] == true
    rescue Ginseng::ConfigError
      return false
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      uri = TootURI.parse(params['uri'])
      uri = NoteURI.parse(params['uri']) unless uri&.valid?
      raise Ginseng::RequestError, "Invalid URL '#{params['uri']}'" unless uri&.valid?
      return uri.to_md if federate?
      return uri.to_md if uri.local?
      return uri.to_s
    end
  end
end
