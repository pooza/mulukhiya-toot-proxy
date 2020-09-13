module Mulukhiya
  class ClippingWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
      @logger = Logger.new
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
      return uri.to_md if uri.public?
      return uri.to_md if uri.local?
      return uri.to_md if federate?
      return uri.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace unless uri
      @logger.error(worker: self.class.to_s, error: e.message, uri: uri.to_s)
      return uri.to_s
    end
  end
end
