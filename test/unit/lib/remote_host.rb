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

    def test_returns_false_when_resolver_raises
      raising = ->(_host) {raise 'getaddrinfo failure'}

      assert_false(RemoteHost.public?('attacker.example', resolver: raising))
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
  end
end
