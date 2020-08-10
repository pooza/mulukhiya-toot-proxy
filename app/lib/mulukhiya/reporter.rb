module Mulukhiya
  class Reporter < Array
    attr_accessor :response, :parser

    attr_reader :temp

    def initialize(size = 0, val = nil)
      super
      @logger = Logger.new
      @temp = {}
    end

    def tags
      @tags ||= TagContainer.new
      return @tags
    end

    def push(entry)
      if entry.is_a?(Handler)
        push(entry.summary) if entry.reportable?
        log(entry.summary) if entry.loggable?
      elsif entry.present?
        super
        @dump = nil
      end
    end

    def log(entry)
      @logger.info(entry)
    end

    def to_h
      unless @dump
        @dump = {}
        each do |v|
          @dump[v[:event]] ||= {}
          @dump[v[:event]][v[:handler]] = v[:entries]
        end
      end
      return @dump
    end

    def to_s
      return to_h.to_yaml
    end
  end
end
