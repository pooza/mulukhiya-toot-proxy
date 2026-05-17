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
  end
end
