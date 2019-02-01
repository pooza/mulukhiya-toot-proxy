module MulukhiyaTootProxy
  class ThinDaemon < Daemon
    def cmd
      return [
        'thin',
        '--config',
        ThinDaemon.config_path,
        'start',
      ]
    end

    def child_pid
      return `pgrep -f #{ThinDaemon.config_path}`.to_i
    end

    def self.config_path
      return File.join(Environment.dir, 'config/thin.yaml')
    end
  end
end
