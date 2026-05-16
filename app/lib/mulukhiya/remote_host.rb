require 'resolv'

module Mulukhiya
  class RemoteHost
    IPV4_LITERAL = /\A\d{1,3}(\.\d{1,3}){3}\z/
    IPV6_BRACKET = /\A\[.*\]\z/

    # DNS 解決・名前解決の失敗（環境要因）。fail-closed で false を返す。
    # IPAddr::Error 等のロジックバグはここに含めず再 raise し Sentry へ送る。
    RESOLUTION_ERRORS = [
      SocketError,
      Resolv::ResolvError,
      Errno::ENOENT,
      Errno::ETIMEDOUT,
    ].freeze

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
    rescue *RESOLUTION_ERRORS => e
      # DNS 障害・タイムアウト等の環境要因は SSRF allowlist の fail-closed
      # 方針どおり false を返す。運用ミス（未到達ホスト等）と攻撃検知の
      # 切り分けのため warn ログを残す。IPAddr::Error 等のロジックバグは
      # ここで握らず呼び出し元へ伝播させ Sentry で可視化する。
      Logger.new.warn(remote_host: {host:, error: e.class.name, message: e.message})
      return false
    end

    def self.resolve_addresses(host)
      return Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address)
    end
  end
end
