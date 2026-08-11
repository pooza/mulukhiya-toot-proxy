module Mulukhiya
  class RemoteHostTest < TestCase
    def stub_resolver(addresses)
      return ->(_host) {addresses}
    end

    def test_returns_false_for_blank_host
      assert_false(RemoteHost.public?(''))
      assert_false(RemoteHost.public?(nil))
    end

    def test_returns_false_for_host_without_dot
      assert_false(RemoteHost.public?('localhost', resolver: stub_resolver(['8.8.8.8'])))
    end

    def test_returns_false_for_ipv4_literal
      assert_false(RemoteHost.public?('127.0.0.1', resolver: stub_resolver(['127.0.0.1'])))
      assert_false(RemoteHost.public?('192.168.1.1', resolver: stub_resolver(['192.168.1.1'])))
    end

    def test_returns_false_for_ipv6_bracket
      assert_false(RemoteHost.public?('[::1]', resolver: stub_resolver(['::1'])))
    end

    def test_returns_false_when_resolver_returns_loopback
      assert_false(RemoteHost.public?('attacker.example', resolver: stub_resolver(['127.0.0.1'])))
    end

    def test_returns_false_when_resolver_returns_private_v4
      assert_false(RemoteHost.public?('attacker.example', resolver: stub_resolver(['10.0.0.1'])))
      assert_false(RemoteHost.public?('attacker.example', resolver: stub_resolver(['172.16.0.1'])))
      assert_false(RemoteHost.public?('attacker.example', resolver: stub_resolver(['192.168.1.1'])))
    end

    def test_returns_false_when_resolver_returns_link_local
      assert_false(RemoteHost.public?('attacker.example', resolver: stub_resolver(['169.254.0.1'])))
    end

    def test_returns_false_when_any_address_is_private
      mixed = ['8.8.8.8', '127.0.0.1']

      assert_false(RemoteHost.public?('attacker.example', resolver: stub_resolver(mixed)))
    end

    # ⚠ ゼロアドレスは private? / loopback? / link_local? のいずれも false を返すのに、
    # connect(2) はローカルホスト宛として扱う。pinning が効いているぶん確実に届く (#4574)。
    def test_returns_false_when_resolver_returns_zero_address
      ['0.0.0.0', '::', '::ffff:0.0.0.0', '0.1.2.3'].each do |address|
        assert_false(
          RemoteHost.public?('attacker.example', resolver: stub_resolver([address])),
          "#{address} を許可してはいけない",
        )
      end
    end

    def test_returns_false_when_resolver_returns_reserved_range
      # ⚠ NAT64 は well-known (RFC 6146) と local-use (RFC 8215) で別レンジ。
      # 前者だけ塞ぐと、local-use を使う環境で内部 IPv4 へ変換されて抜ける。
      addresses = [
        '100.64.0.1', '192.0.0.1', '198.18.0.1', '224.0.0.1', '255.255.255.255',
        '64:ff9b::7f00:1', '64:ff9b:1::7f00:1'
      ]

      addresses.each do |address|
        assert_false(
          RemoteHost.public?('attacker.example', resolver: stub_resolver([address])),
          "#{address} を許可してはいけない",
        )
      end
    end

    # 予約レンジを足したせいで正当な公開アドレスまで落ちていないこと。
    def test_returns_true_for_public_addresses_outside_reserved_ranges
      ['8.8.8.8', '93.184.216.34', '2606:2800:220:1:248:1893:25c8:1946'].each do |address|
        assert_true(
          RemoteHost.public?('example.com', resolver: stub_resolver([address])),
          "#{address} は許可されるべき",
        )
      end
    end

    def test_returns_false_when_resolver_returns_empty
      assert_false(RemoteHost.public?('nx.example', resolver: stub_resolver([])))
    end

    def test_returns_false_when_resolver_raises_dns_error
      [SocketError, Resolv::ResolvError, Errno::ENOENT, Errno::ETIMEDOUT].each do |klass|
        raising = ->(_host) {raise klass, 'getaddrinfo failure'}

        assert_false(
          RemoteHost.public?('attacker.example', resolver: raising),
          "#{klass} は fail-closed で false を返すべき",
        )
      end
    end

    def test_reraises_non_dns_error
      # IPAddr::Error 等のロジックバグは握り潰さず Sentry へ伝播させる。
      raising = ->(_host) {raise IPAddr::InvalidAddressError, 'broken resolver'}

      assert_raise(IPAddr::InvalidAddressError) do
        RemoteHost.public?('attacker.example', resolver: raising)
      end
    end

    def test_returns_true_for_public_address
      assert_true(RemoteHost.public?('example.com', resolver: stub_resolver(['93.184.216.34'])))
    end

    def test_idn_punycode_resolved_to_private_is_blocked
      # IDN homograph (e.g. xn--google-yvc.com) — defense relies on the actual
      # resolved IP, not the visible name. If DNS returns a private address we
      # block regardless of how legitimate the hostname looks.
      assert_false(RemoteHost.public?('xn--google-yvc.com', resolver: stub_resolver(['10.0.0.5'])))
    end

    def test_dns_timeout_returns_configured_value
      assert_kind_of(Numeric, RemoteHost.dns_timeout)
      assert_equal(Config.instance['/remote_host/dns/timeout'], RemoteHost.dns_timeout)
    end

    def test_resolve_addresses_applies_timeout_and_maps_to_strings
      applied = nil
      fake = Object.new
      fake.define_singleton_method(:timeouts=) {|v| applied = v}
      fake.define_singleton_method(:getaddresses) do |_host|
        [Resolv::IPv4.create('93.184.216.34'), Resolv::IPv6.create('2606:2800:220:1::1')]
      end
      fake.define_singleton_method(:close) {nil}
      original = Resolv::DNS.method(:new)
      Resolv::DNS.define_singleton_method(:new) {|*| fake}
      begin
        result = RemoteHost.resolve_addresses('example.com')
      ensure
        Resolv::DNS.define_singleton_method(:new, original)
      end

      assert_equal(RemoteHost.dns_timeout, applied)
      assert_equal(['93.184.216.34', '2606:2800:220:1::1'], result)
    end

    # ⚠ **allowed_address が返すのは真偽値でなく接続先の IP** (#4524)。
    # 名前で検証して名前で接続すると、権威 DNS を握った相手が検証時だけ公開 IP を
    # 返し、接続時に 127.0.0.1 を返せる（DNS リバインディング）。
    def test_allowed_address_returns_resolved_address
      assert_equal(
        '93.184.216.34',
        RemoteHost.allowed_address('example.com', resolver: stub_resolver(['93.184.216.34'])),
      )
    end

    def test_allowed_address_returns_nil_for_rejected_host
      assert_nil(RemoteHost.allowed_address('attacker.example', resolver: stub_resolver(['127.0.0.1'])))
      assert_nil(RemoteHost.allowed_address('nx.example', resolver: stub_resolver([])))
      assert_nil(RemoteHost.allowed_address('localhost', resolver: stub_resolver(['8.8.8.8'])))
    end

    # ⚠ IPv4 があれば IPv4 を採る。getaddresses は A と AAAA を混ぜて返すので、
    # 素直に先頭を採ると IPv6 を掴んで到達しない／遅くなる。
    def test_allowed_address_prefers_ipv4
      mixed = ['2606:2800:220:1::1', '93.184.216.34']

      assert_equal(
        '93.184.216.34',
        RemoteHost.allowed_address('example.com', resolver: stub_resolver(mixed)),
      )
    end

    def test_allowed_address_falls_back_to_ipv6_only
      assert_equal(
        '2606:2800:220:1::1',
        RemoteHost.allowed_address('example.com', resolver: stub_resolver(['2606:2800:220:1::1'])),
      )
    end

    # DNS 障害は fail-closed（nil = 拒否）。真偽値へ倒して true にしない。
    def test_allowed_address_is_nil_on_dns_error
      raising = ->(_host) {raise Resolv::ResolvError, 'timeout'}

      assert_nil(RemoteHost.allowed_address('attacker.example', resolver: raising))
    end

    # validator は ginseng-core の host_validator へ渡る callable。**真偽値でなく
    # IP を返す**とあちらが接続先を固定する (pooza/ginseng-core#503)。
    # ⚠ 実 DNS を引かせないよう、解決前に弾かれる入力で確かめる。
    def test_validator_rejects_without_resolving
      assert_nil(RemoteHost.validator.call('127.0.0.1'))
      assert_nil(RemoteHost.validator.call('localhost'))
      assert_nil(RemoteHost.validator.call(''))
    end

    # 解決できた場合にアドレスが返ること（resolver を差し替えて確認する）。
    def test_validator_returns_address_when_allowed
      original = RemoteHost.method(:resolve_addresses)
      RemoteHost.define_singleton_method(:resolve_addresses) {|_host| ['93.184.216.34']}
      begin
        assert_equal('93.184.216.34', RemoteHost.validator.call('example.com'))
      ensure
        RemoteHost.define_singleton_method(:resolve_addresses, original)
      end
    end

    # validate! は allowlist 拒否を「判定不能」と区別するための入口 (#4535)。
    # 拒否したときに **実際に例外になる**ことを正で押さえる。
    def test_validate_raises_for_rejected_host
      RemoteHost.validator = ->(_host) {false}

      assert_raise(Ginseng::GatewayError) do
        RemoteHost.validate!(Ginseng::URI.parse('http://169.254.169.254/latest/meta-data/'))
      end
    ensure
      RemoteHost.validator = nil
    end

    def test_validate_passes_for_permitted_host
      RemoteHost.validator = ->(host) {host == 'www.example.jp'}

      assert_true(RemoteHost.validate!(Ginseng::URI.parse('https://www.example.jp/foo')))
      assert_true(RemoteHost.validate!('www.example.jp'))
    ensure
      RemoteHost.validator = nil
    end
  end
end
