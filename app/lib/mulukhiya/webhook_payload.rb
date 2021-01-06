module Mulukhiya
  class WebhookPayload
    include Package
    include SNSMethods
    attr_reader :raw

    def initialize(values)
      @raw = JSON.parse(values) unless values.is_a?(Hash)
      @raw ||= values.deep_stringify_keys
    end

    def contract
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def method_missing(method, *args)
      return raw[method.to_s] if args.empty?
      return super
    end

    def respond_to_missing?(method, *args)
      return args.empty? if args.is_a?(Array)
      return super
    end

    def values
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
