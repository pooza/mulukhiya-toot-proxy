module Mulukhiya
  class SidekiqDaemon < Daemon
    def command
      return CommandLine.new(
        ['sidekiq', '--config', config_cache_path, '--require', initializer_path],
      )
    end

    def initializer_path
      return File.join(Environment.dir, 'app/initializer/sidekiq.rb')
    end

    def motd
      return [
        `sidekiq -V`.chomp,
        "Redis DSN: #{@config['/sidekiq/redis/dsn']}",
      ].join("\n")
    end
  end
end
