module MulukhiyaTootProxy
  class SidekiqDaemon < Daemon
    def cmd
      return [
        'sidekiq',
        '--config',
        File.join(Environment.dir, 'config/sidekiq.yaml'),
        '--require',
        File.join(Environment.dir, 'lib/initializer/sidekiq.rb'),
      ]
    end

    def child_pid
      return File.read(SidekiqDaemon.pid_path).to_i
    end

    def self.pid_path
      return File.join(Environment.dir, 'tmp/pids/sidekiq.pid')
    end
  end
end
