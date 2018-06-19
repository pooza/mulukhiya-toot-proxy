require 'json'
require 'syslog/logger'
require 'mulukhiya-toot-proxy/package'

module MulukhiyaTootProxy
  class Logger
    def initialize
      @logger = Syslog::Logger.new(Package.name)
    end

    def info(message)
      @logger.info(jsonize(message))
    end

    def warning(message)
      @logger.warn(jsonize(message))
    end

    def error(message)
      @logger.error(jsonize(message))
    end

    def fatal(message)
      @logger.fatal(jsonize(message))
    end

    private

    def jsonize(message)
      message = message.clone
      message['package'] = {name: Package.name, version: Package.version}
      return message.to_json
    end
  end
end
