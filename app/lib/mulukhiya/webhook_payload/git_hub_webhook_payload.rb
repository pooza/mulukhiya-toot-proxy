module Mulukhiya
  class GitHubWebhookPayload
    include Package
    attr_reader :raw

    def initialize(values)
      @raw = JSON.parse(values) unless values.is_a?(Hash)
      @raw ||= values.deep_stringify_keys
    end

    def errors
      @errors ||= GitHubWebhookContract.new.exec(@raw)
      return @errors
    end

    def values
      return {Environment.controller_class.status_field => @raw.to_json}
    end

    alias to_h values
  end
end
