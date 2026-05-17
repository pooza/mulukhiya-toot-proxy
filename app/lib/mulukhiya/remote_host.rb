require 'resolv'

module Mulukhiya
  class RemoteHost
    IPV4_LITERAL = /\A\d{1,3}(\.\d{1,3}){3}\z/
    IPV6_BRACKET = /\A\[.*\]\z/
    DEFAULT_DNS_TIMEOUT = 3

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

    # Addrinfo.getaddrinfo は timeout を持てず、攻撃者が応答を引き延ばす権威
    # DNS を立てると Sinatra リクエストスレッド (Puma 5 本) を飽和させられる。
    # Resolv::DNS#timeouts= で 1 回あたりの解決待ちを上限化する。タイムアウト
    # 時 getaddresses は空配列を返すため、public? は addrs.empty? で
    # fail-closed (false) に倒れる。
    def self.resolve_addresses(host)
      resolver = Resolv::DNS.new
      resolver.timeouts = dns_timeout
      return resolver.getaddresses(host).map(&:to_s)
    ensure
      resolver&.close
    end

    def self.dns_timeout
      return Config.instance['/remote_host/dns/timeout'] || DEFAULT_DNS_TIMEOUT
    end
  end
end
