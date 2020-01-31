module Mulukhiya
  class ResultContainer < Array
    attr_accessor :response
    attr_accessor :parser

    def tags
      @tags ||= TagContainer.new
      return @tags
    end

    def push(value)
      return unless value
      @logger ||= Logger.new
      @logger.info(value)
      super(value)
    end
  end
end
