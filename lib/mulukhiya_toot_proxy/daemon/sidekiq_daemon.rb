require 'daemon_spawn'

module MulukhiyaTootProxy
  class SidekiqDaemon < DaemonSpawn::Base
    def start(args)
      system(
        'sidekiq',
        '--config',
        File.join(Environment.dir, 'config/sidekiq.yaml'),
        '--require',
        File.join(Environment.dir, 'sidekiq.rb'),
        '&',
      )
    end

    def stop
      Process.kill('KILL', SidekiqDaemon.pid)
    end

    def self.pid
      return File.read(SidekiqDaemon.pid_path).to_i
    end

    def self.pid_path
      return File.join(Environment.dir, 'tmp/pids/sidekiq.pid')
    end
  end
end
