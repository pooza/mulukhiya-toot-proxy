module MulukhiyaTootProxy
  class ThinDaemon < Daemon
    def start(args)
      IO.popen(['thin', '--config', ThinDaemon.config_path, 'start']).each_line do |line|
        @logger.info({daemon: app_name, output: line.chomp})
      end
    end

    def stop
      system('pkill', '-f', ThinDaemon.config_path)
    end

    def self.config_path
      return File.join(Environment.dir, 'config/thin.yaml')
    end
  end
end
