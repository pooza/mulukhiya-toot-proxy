module Mulukhiya
  class RemoteHost
    IPV4_LITERAL = /\A\d{1,3}(\.\d{1,3}){3}\z/
    IPV6_BRACKET = /\A\[.*\]\z/

    def self.public?(host, resolver: method(:resolve_addresses))
      return false unless host.present?
      return false unless host.include?('.')
      return false if IPV4_LITERAL.match?(host)
      return false if IPV6_BRACKET.match?(host)
      addrs = resolver.call(host)
      return false if addrs.empty?
      addrs.none? do |ip|
        addr = IPAddr.new(ip)
        addr.private? || addr.loopback? || addr.link_local?
      end
    rescue => e
      # SSRF allowlist の fail-closed 方針は維持しつつ、DNS 障害・タイムアウト・
      # 内部例外 (IPAddr 等) の切り分けができるよう warn ログだけ残す。
      Logger.new.warn(remote_host: {host:, error: e.class.name, message: e.message})
      return false
    end

    def self.resolve_addresses(host)
      return Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address)
    end
  end
end
