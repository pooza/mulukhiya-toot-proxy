module Mulukhiya
  class ListenerDaemon < Ginseng::Daemon
    include Package
    include SNSMethods

    def start(args = [])
      save_config
      return Environment.listener_class.start
    end

    def command
      return CommandLine.new([
        File.join(Environment.dir, 'bin/listener_worker.rb'),
      ])
    end

    def self.disable?
      return true unless Environment.dbms_class&.config?
      return true unless Environment.account_class.info_token
      return true if [:follow, :mention].sum {|v| Event.new(v).count}.zero?
      return false
    end

    def self.restart
      return CommandLine.new([File.join(Environment.dir, 'bin/listener_daemon.rb'), 'restart'])
          .exec(timeout: config['/daemon/restart/timeout/seconds'])
    end

    def self.health
      pid_path = File.join(Environment.dir, 'tmp/pids/ListenerDaemon.pid')
      if File.exist?(pid_path)
        pid = File.read(pid_path).to_i
        raise "PID '#{pid}' was dead" unless Process.alive?(pid)
      else
        unless system('pgrep', '-f', 'listener_daemon.rb',
          out: File::NULL, err: File::NULL)
          raise 'listener process not found'
        end
      end
      check_streaming_endpoint if Environment.mastodon?
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end

    def self.check_streaming_endpoint
      uri = Ginseng::URI.parse(config['/mastodon/url'])
      uri.path = '/api/v1/streaming/health'
      response = HTTP.new.get(uri)
      raise "streaming returned #{response.code}" unless response.code == 200
    end
  end
end
