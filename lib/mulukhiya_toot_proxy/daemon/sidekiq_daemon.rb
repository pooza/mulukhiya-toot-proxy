module MulukhiyaTootProxy
  class SidekiqDaemon < Daemon
    def start(args)
      cmd = [
        'sidekiq',
        '--config',
        File.join(Environment.dir, 'config/sidekiq.yaml'),
        '--require',
        File.join(Environment.dir, 'lib/initializer/sidekiq.rb'),
      ]
      IO.popen(cmd).each_line do |line|
        @logger.info({daemon: app_name, output: line.chomp})
      end
    end

    def stop
      Process.kill('KILL', SidekiqDaemon.pid)
    end

    def self.pid
      return File.read(pid_path).to_i
    end

    def self.pid_path
      return File.join(Environment.dir, 'tmp/pids/sidekiq.pid')
    end
  end
end
