module Mulukhiya
  class Logger < Ginseng::Logger
    include Package

    def error(log)
      super(log)
      return unless log.is_a?(StandardError)
      log.backtrace.each do |entry|
        super(entry)
      end
    end
  end
end
