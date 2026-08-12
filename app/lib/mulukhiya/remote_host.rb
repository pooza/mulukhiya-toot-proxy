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

    # IPAddr の private? / loopback? / link_local? が拾わない予約・特殊用途レンジ (#4574)。
    #
    # ⚠ **`0.0.0.0` は 3 述語のいずれも false を返す**のに、Linux / BSD の connect(2) は
    # ローカルホスト宛として扱う。pinning は検証したアドレスへ接続を固定するので、
    # ここを開けたままだと「公開ホスト名なのに localhost へ繋ぐ」経路が決定的に通る。
    # `::`（IPv6 未指定アドレス）も同じ。
    #
    # ⚠ **CGNAT / NAT64 は本番 4 台では実害に届かない**が、Linode の一部リージョンや
    # 将来の CT 群では内部へ届きうるので同じ表で塞いでおく。
    RESERVED_RANGES = [
      '0.0.0.0/8',          # this-network (0.0.0.0 を含む)
      '100.64.0.0/10',      # CGNAT (RFC 6598)
      '192.0.0.0/24',       # IETF protocol assignments
      '198.18.0.0/15',      # benchmarking (RFC 2544)
      '224.0.0.0/4',        # multicast
      '240.0.0.0/4',        # reserved (255.255.255.255 を含む)
      '::/128',             # unspecified
      '64:ff9b::/96',       # NAT64 well-known prefix (RFC 6146)
      '64:ff9b:1::/48',     # NAT64 local-use prefix (RFC 8215)
      'ff00::/8',           # IPv6 multicast
    ].map {|v| IPAddr.new(v)}.freeze

    def self.public?(host, resolver: method(:resolve_addresses))
      return allowed_address(host, resolver:).present?
    end

    # 許可できるなら**接続に使う IP アドレス**を、拒否なら nil を返す (#4524)。
    #
    # ⚠ **真偽値ではなくアドレスを返すのが肝。**名前で検証して名前で接続すると、
    # 権威 DNS を握った相手が検証時だけ公開 IP アドレスを返し、接続時に 127.0.0.1 を
    # 返せる（DNS リバインディング / TOCTOU）。ここで通した IP アドレスをそのまま接続先へ
    # 固定する（pinning は pooza/ginseng-core#503）。
    #
    # ⚠ **1 本に固定するので Net::HTTP の複数アドレスへのフォールバックは効かなく
    # なる。**A レコードが複数あって先頭だけ落ちている相手は取得できない。
    # allowlist の対象は管理者が設定した少数の URL なので、この不便より
    # 「検証した先に繋ぐ」ほうを採る。
    def self.allowed_address(host, resolver: method(:resolve_addresses))
      return nil unless host.present?
      return nil unless host.include?('.')
      return nil if IPV4_LITERAL.match?(host)
      return nil if IPV6_BRACKET.match?(host)
      addrs = resolver.call(host)
      return nil if addrs.empty?
      # ⚠ 1 本でも内部アドレスを含むなら拒否する。「公開 IP アドレスのほうを選べばよい」
      # ではない。混ぜて返してくるのはリバインディングそのもの。
      return nil if addrs.any? {|ip| internal_address?(ip)}
      return preferred_address(addrs)
    rescue *RESOLUTION_ERRORS => e
      # DNS 障害・タイムアウト等の環境要因は SSRF allowlist の fail-closed
      # 方針どおり nil（= 拒否）を返す。運用ミス（未到達ホスト等）と攻撃検知の
      # 切り分けのため warn ログを残す。IPAddr::Error 等のロジックバグは
      # ここで握らず呼び出し元へ伝播させ Sentry で可視化する。
      Logger.new.warn(remote_host: {host:, error: e.class.name, message: e.message})
      return nil
    end

    def self.internal_address?(ip)
      addr = IPAddr.new(ip)
      # ⚠ IPv4-mapped / IPv4-compatible は IPv6 として扱われるので、先に素の IPv4 へ
      # 畳んでからレンジと突き合わせる。畳まないと ::ffff:0.0.0.0 が
      # RESERVED_RANGES の 0.0.0.0/8 と family 違いで一致しない (#4574)。
      addr = addr.native if addr.ipv4_mapped? || addr.ipv4_compat?
      return true if addr.private? || addr.loopback? || addr.link_local?
      return RESERVED_RANGES.any? {|range| range.include?(addr)}
    end

    # ⚠ IPv4 があれば IPv4 を採る。getaddresses は A と AAAA を混ぜて返すので、
    # 素直に先頭を採ると IPv6 が来うる。モロヘイヤが動く本番 4 台は IPv4 を正と
    # しており、IPv6 を掴むと到達しないか Happy Eyeballs のフォールバックぶんだけ
    # 遅くなる（#4464 で踏んだ ::1 の 305ms と同じ形）。
    def self.preferred_address(addrs)
      return addrs.find {|ip| IPV4_LITERAL.match?(ip)} || addrs.first
    end

    # Ginseng::HTTP#get の host_validator へ渡す callable (#4410)。
    # リダイレクトの各ホップがこれを通る。
    #
    # ⚠ **返すのは真偽値ではなく IP アドレス**（拒否なら nil）。ginseng-core は
    # 文字列が返るとその IP アドレスへ接続を固定する (pooza/ginseng-core#503)。名前で
    # 検証して名前で接続していると DNS リバインディングで抜けられる (#4524)。
    #
    # ⚠ writer はテストの差し替え専用。実行時に緩めてはいけない。差し替えた
    # テストは teardown で必ず元へ戻すこと（残すと以後のテストで SSRF ガードが
    # 効かなくなり、守れているつもりの緑になる）。
    def self.validator
      @validator ||= ->(host) {allowed_address(host)}
      return @validator
    end

    class << self
      attr_writer :validator
    end

    # allowlist を通らないホストで GatewayError を投げる (#4535)。
    #
    # HEAD プリフライトの rescue は「HEAD 非対応・一過性障害 = 判定不能」を
    # GET へ倒すためのもの。allowlist 拒否まで同じ rescue が飲むと
    # 「プリフライトが true = GET してよい」が成り立たなくなり、GET 側の
    # host_validator が外れた瞬間に無検証へ戻る。拒否は HEAD を撃つ前に
    # ここで確定させ、URL 単位の rescue へ渡す（拒否 1 件につきログも 1 本）。
    def self.validate!(uri)
      host = uri.respond_to?(:host) ? uri.host.to_s : uri.to_s
      return true if validator.call(host)
      raise Ginseng::GatewayError, "Rejected host '#{host}'"
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
