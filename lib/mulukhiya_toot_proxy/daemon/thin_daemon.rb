require 'daemon_spawn'

module MulukhiyaTootProxy
  class ThinDaemon < DaemonSpawn::Base
    def start(args)
      system(
        'thin',
        '--config',
        File.join(Environment.dir, 'config/thin.yaml'),
        'start',
      )
    end

    def stop
      system(
        'pkill',
        '-f',
        File.join(Environment.dir, 'config/thin.yaml'),
      )
    end
  end
end
