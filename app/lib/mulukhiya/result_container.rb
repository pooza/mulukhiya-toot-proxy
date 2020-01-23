module Mulukhiya
  class ResultContainer < Array
    attr_accessor :response
    attr_accessor :parser

    def summary
      return map {|v| "#{v[:handler]}:#{v.count}"}.join(', ')
    end

    def push(value)
      return unless value
      @logger ||= Logger.new
      @logger.info(value)
      super(value)
    end
  end
end
