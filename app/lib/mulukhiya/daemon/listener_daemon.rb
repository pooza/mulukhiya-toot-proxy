module Mulukhiya
  class ListenerDaemon < Ginseng::Daemon
    include Package
    include SNSMethods

    def command
      return CommandLine.new([
        File.join(Environment.dir, 'bin/listener_worker.rb'),
      ])
    end

    def motd
      return [
        "#{self.class} #{Package.version}",
        "Streaming API URL: #{service.create_streaming_uri}",
      ].join("\n")
    end

    def service
      @service ||= info_agent_service
      return @service
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
