module Mulukhiya
  class Reporter < Array
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

    def push(entry)
      return unless entry.present?
      super(entry)
      @logger.info(entry)
      @dump = nil
    end

    def to_h
      unless @dump
        @dump = {}
        each do |entry|
          next if entry[:verbose] && !@account&.notify_verbose? && !entry[:errors].present?
          @dump[entry[:event]] ||= {}
          @dump[entry[:event]][entry[:handler]] ||= []
          [:result, :errors].each do |key|
            @dump[entry[:event]][entry[:handler]].concat(
              entry[key].map do |v|
                v.is_a?(Hash) ? v.deep_stringify_keys : v
              end,
            )
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
