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

    def motd
      return [
        `sidekiq -V`.chomp,
        "Redis DSN: #{@config['/sidekiq/redis/dsn']}",
      ].join("\n")
    end

    def self.config
      return Config.instance
    end

    def self.username
      return config['/sidekiq/auth/user']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.password
      return config['/sidekiq/auth/password']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.basic_auth?
      return username.present? && password.present?
    end

    def self.auth(username, password)
      return true unless basic_auth?
      return false unless username == self.username
      return true if password == self.password.decrypt
      return true if password.crypt(Environment.hostname) == self.password
      return true if password == self.password
      return false
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

    private

    def initializer_path
      return File.join(Environment.dir, 'app/initializer/sidekiq.rb')
    end

    def create_log_entry(line)
      return {daemon: app_name}.merge(JSON.parse(line))
    rescue
      return super
    end
  end
end
