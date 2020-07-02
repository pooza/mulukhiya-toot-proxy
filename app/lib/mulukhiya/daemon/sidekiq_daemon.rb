require 'sidekiq/api'

module Mulukhiya
  class SidekiqDaemon < Ginseng::Daemon
    include Package

    def command
      return CommandLine.new([
        'sidekiq',
        '--config', config_cache_path,
        '--require', initializer_path
      ])
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

    def self.health
      stats = Sidekiq::Stats.new
      pids = Sidekiq::ProcessSet.new.map {|p| p['pid']}
      values = {
        queues: stats.queues['default'],
        retry: stats.retry_size,
        status: pids.present? ? 'OK' : 'NG',
      }
      pids.each do |pid|
        raise "PID '#{pid}' not alive" unless Process.alive?(pid)
      end
      return values
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
