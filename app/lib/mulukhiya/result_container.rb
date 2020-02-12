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

    def push(result)
      return unless result.present?
      super(result)
      @logger.info(result)
      @dump = nil
    end

    def to_h
      unless @dump
        @dump = {}
        each do |result|
          next unless result[:notifiable] || @account&.notify_verbose?
          @dump[result[:event]] ||= {}
          @dump[result[:event]][result[:handler]] = result[:entries].map do |v|
            v.is_a?(Hash) ? v.deep_stringify_keys : v
          end
        end
      end
      return @dump
    end

    def to_s
      return to_h.to_yaml
    end
  end
end
