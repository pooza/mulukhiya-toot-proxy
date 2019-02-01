require 'daemon_spawn'

module MulukhiyaTootProxy
  class Daemon < DaemonSpawn::Base
    def initialize(opts = {})
      @logger = Logger.new
      opts[:application] ||= classname
      opts[:working_dir] ||= Environment.dir
      super(opts)
    end

    def start(args)
      IO.popen(cmd).each_line do |line|
        @logger.info({daemon: app_name, output: line.chomp})
      end
    end

    def stop
      Process.kill('KILL', child_pid)
    end

    def cmd
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def child_pid
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def fork!(args)
      Process.setsid
      exit if fork
      File.write(pid_file, Process.pid.to_s)
      Dir.chdir(working_dir)
      trap('TERM') do
        stop
        exit
      end
      start(args)
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
          daemon.fork!(args)
        end
      end
    end
  end
end
