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
      Process.kill('KILL', File.read(File.join(Environment.dir, 'tmp/pids/sidekiq.pid')).to_i)
    end
  end
end
