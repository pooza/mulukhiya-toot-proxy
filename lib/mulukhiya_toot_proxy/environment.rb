require 'socket'

module MulukhiyaTootProxy
  class Environment
    def self.name
      return File.basename(ROOT_DIR)
    end

    def self.hostname
      return Socket.gethostname
    end

    def self.ip_address
      udp = UDPSocket.new
      udp.connect('128.0.0.0', 7)
      addr = Socket.unpack_sockaddr_in(udp.getsockname)[1]
      udp.close
      return addr
    end

    def self.platform
      return 'Debian' if File.executable?('/usr/bin/apt-get')
      return `uname`.chomp
    end

    def self.cron?
      return ENV.member?('CRON') && (ENV['CRON'] != '')
    end

    def self.uid
      return File.stat(ROOT_DIR).uid
    end

    def self.gid
      return File.stat(ROOT_DIR).gid
    end
  end
end
