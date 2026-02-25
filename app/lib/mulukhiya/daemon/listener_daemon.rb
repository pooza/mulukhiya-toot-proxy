module Mulukhiya
  class ListenerDaemon < Ginseng::Daemon
    include Package
    include SNSMethods

    def start(args)
      save_config
      Environment.listener_class.start
    end

    def command
      return CommandLine.new([
        File.join(Environment.dir, 'bin/listener_worker.rb'),
      ])
    end

    def motd
      return [
        "#{self.class} #{Package.version}",
        ('Ruby YJIT: Ready' if Environment.jit?),
      ].compact.join("\n")
    end

    def self.disable?
      return true unless Environment.dbms_class&.config?
      return true unless Environment.account_class.info_token
      return true if [:follow, :mention].sum {|v| Event.new(v).count}.zero?
      return false
    end

    def self.restart
      CommandLine.new([File.join(Environment.dir, 'bin/listener_daemon.rb'), 'restart']).exec
    end

    def self.health
      pid = File.read(File.join(Environment.dir, 'tmp/pids/ListenerDaemon.pid')).to_i
      raise "PID '#{pid}' was dead" unless Process.alive?(pid)
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
