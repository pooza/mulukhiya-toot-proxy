module Mulukhiya
  class PumaDaemon < Daemon
    def command
      return CommandLine.new(['puma', '--config', config_file])
    end

    def config_file
      return File.join(Environment.dir, 'app/initializer/puma.rb')
    end

    def motd
      return [
        `puma -V`.chomp,
        "Root URL: #{root_uri}",
      ].join("\n")
    end

    def root_uri
      unless @uri
        @uri = Ginseng::URI.new
        @uri.host = Environment.hostname
        @uri.scheme = 'http'
        @uri.port = @config['/puma/port']
      end
      return @uri
    end
  end
end
