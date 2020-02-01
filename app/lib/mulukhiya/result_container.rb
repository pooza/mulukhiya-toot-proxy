module Mulukhiya
  class ResultContainer < Array
    attr_accessor :response
    attr_accessor :parser
    attr_accessor :account

    def initialize(size = 0, val = nil)
      super(size, val)
      @logger = Logger.new
    end

    def tags
      @tags ||= TagContainer.new
      return @tags
    end

    def push(values)
      return unless values.present?
      super(values)
      @logger.info(values)
    end

    def to_h
      h = {}
      each do |values|
        h[values[:event]] ||= {}
        h[values[:event]][values[:handler]] = values[:entries].map do |v|
          v.is_a?(Hash) ? v.deep_stringify_keys : v
        end
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(v: values))
      end
      return h
    end

    def to_s
      body = [YAML.dump(to_h)]
      body.unshift(Environment.account_class[account.id].acct.to_s) if account
      return body.join("\n")
    end
  end
end
