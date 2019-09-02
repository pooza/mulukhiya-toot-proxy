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

    def self.config_path
      return File.join(Environment.dir, 'config/thin.yaml')
    end
  end
end
