require 'addressable/uri'

module MulukhiyaTootProxy
  class ThinDaemon < Ginseng::Daemon
    include Package

    def cmd
      return [
        'thin',
        '--config',
        ThinDaemon.config_path,
        'start',
      ]
    end

    def child_pid
      return `pgrep -f #{ThinDaemon.config_path}`.to_i
    end

    def motd
      return [
        `thin -v`.chomp,
        "Root URL: #{root_uri}",
      ].join("\n")
    end

    def root_uri
      unless @uri
        @uri = Addressable::URI.new
        @uri.host = Environment.hostname
        @uri.scheme = 'http'
        @uri.port = @config['/thin/port']
      end
      return @uri
    end

    def self.config_path
      return File.join(Environment.dir, 'config/thin.yaml')
    end
  end
end
