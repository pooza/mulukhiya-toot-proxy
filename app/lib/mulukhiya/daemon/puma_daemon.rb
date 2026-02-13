module Mulukhiya
  class PumaDaemon < Ginseng::Daemon
    include Package

    def command
      return CommandLine.new([
        'puma',
        '--config', initializer_path
      ])
    end

    def motd
      return [
        `puma -V`.chomp,
        "Root URL: #{root_uri}",
        ("PostgreSQL DSN: #{secure_dsn(config['/postgres/dsn'])}" rescue nil),
        ("Redis DSN: #{secure_dsn(config['/user_config/redis/dsn'])}" rescue nil),
        ('Ruby YJIT: Ready' if Environment.jit?),
      ].compact.join("\n")
    end

    def root_uri
      unless @uri
        @uri = Ginseng::URI.new
        @uri.host = Environment.hostname
        @uri.scheme = 'http'
        @uri.port = config['/puma/port']
      end
      return @uri
    end

    def self.disable?
      return false
    end

    def self.restart
      CommandLine.new(['rake', 'mulukhiya:puma:restart']).exec
    end

    private

    def initializer_path
      return File.join(Environment.dir, 'app/initializer/puma.rb')
    end

    def secure_dsn(dsn)
      dsn = Ginseng::URI.parse(dsn) unless dsn.is_a?(Ginseng::URI)
      dsn.password = '***' if dsn.password
      return dsn
    end
  end
end
