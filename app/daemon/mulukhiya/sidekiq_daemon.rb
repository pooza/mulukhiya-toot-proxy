module Mulukhiya
  class SidekiqDaemon < Ginseng::Daemon
    include Package

    def cmd
      return [
        'sidekiq',
        '--config',
        File.join(Environment.dir, 'config/sidekiq.yaml'),
        '--require',
        File.join(Environment.dir, 'app/initializer/sidekiq.rb'),
      ]
    end

    def motd
      return [
        `sidekiq -V`.chomp,
        "Redis DSN: #{@config['/sidekiq/redis/dsn']}",
      ].join("\n")
    end
  end
end
