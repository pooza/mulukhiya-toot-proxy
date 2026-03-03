module Mulukhiya
  class PumaDaemon < Ginseng::Daemon
    include Package

    def command
      return CommandLine.new([
        'puma',
        '--config', initializer_path
      ])
    end

    def self.disable?
      return false
    end

    def self.restart
      CommandLine.new([File.join(Environment.dir, 'bin/puma_daemon.rb'), 'restart'])
        .exec(timeout: config['/daemon/restart/timeout/seconds'])
    end

    private

    def initializer_path
      return File.join(Environment.dir, 'app/initializer/puma.rb')
    end
  end
end
