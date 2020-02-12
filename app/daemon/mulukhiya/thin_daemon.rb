module Mulukhiya
  class ThinDaemon < Daemon
    def command
      return CommandLine.new(['thin', '--config', config_cache_path, 'start'])
    end

    def motd
      return [
        `thin -v`.chomp,
        "Root URL: #{root_uri}",
      ].join("\n")
    end

    def root_uri
      unless @uri
        @uri = Ginseng::URI.new
        @uri.host = Environment.hostname
        @uri.scheme = 'http'
        @uri.port = @config['/thin/port']
      end
      return @uri
    end
  end
end
