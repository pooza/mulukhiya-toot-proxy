require 'socket'

module MulukhiyaTootProxy
  class Environment
    def self.name
      return File.basename(dir)
    end

    def self.hostname
      return Socket.gethostname
    end

    def self.dir
      return File.expand_path('../..', __dir__)
    end

    def self.ip_address
      udp = UDPSocket.new
      udp.connect('128.0.0.0', 7)
      return Socket.unpack_sockaddr_in(udp.getsockname)[1]
    ensure
      udp.close
    end

    def self.platform
      return 'Debian' if File.executable?('/usr/bin/apt-get')
      return `uname`.chomp
    end

    def self.cron?
      return ENV['CRON'].present?
    rescue
      return false
    end

    def self.uid
      return File.stat(dir).uid
    end

    def self.gid
      return File.stat(dir).gid
    end
  end
end
