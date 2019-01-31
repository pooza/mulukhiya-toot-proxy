require 'daemon_spawn'

module MulukhiyaTootProxy
  class Daemon < DaemonSpawn::Base
    def initialize(opts = {})
      opts[:application] ||= classname
      opts[:working_dir] ||= Environment.dir
      super(opts)
    end

    def self.start(opts, args)
      living_daemons = find(opts).select(&:alive?)
      if living_daemons.any?
        raise "#{daemon.app_name} already started! PIDS: #{living_daemons.map(&:pid).join(', ')}"
      end
      build(opts).map do |daemon|
        unless File.writable?(File.dirname(daemon.pid_file))
          raise "Unable to write PID file to #{daemon.pid_file}"
        end
        raise "#{daemon.app_name} is already running (PID #{daemon.pid})" if daemon.alive?
        fork do
          start_daemon(daemon, args)
        end
      end
    end

    def self.start_daemon(daemon, args)
      Process.setsid
      exit if fork
      File.write(daemon.pid_file, Process.pid.to_s)
      Dir.chdir daemon.working_dir
      STDOUT.reopen('/dev/null')
      STDERR.reopen('/dev/null')
      trap('TERM') do
        daemon.stop
        exit
      end
      daemon.start(args)
    end
  end
end
