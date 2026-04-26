module Mulukhiya
  class SwSubscriptionContractTest < TestCase
    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def setup
      @contract = SwSubscriptionContract.new
      @valid = {
        endpoint: 'https://example.com/push/token',
        auth: 'x' * 22,
        publickey: 'y' * 87,
      }
    end

    def test_valid
      errors = @contract.call(@valid).errors

      assert_empty(errors)
    end

    def test_with_send_read_message
      errors = @contract.call(@valid.merge(sendReadMessage: true)).errors

      assert_empty(errors)
    end

    def test_missing_endpoint
      errors = @contract.call(@valid.except(:endpoint)).errors

      assert_false(errors.empty?)
    end

    def test_non_https_endpoint
      errors = @contract.call(@valid.merge(endpoint: 'http://example.com/')).errors

      assert_false(errors.empty?)
    end

    def test_empty_auth
      errors = @contract.call(@valid.merge(auth: '')).errors

      assert_false(errors.empty?)
    end

    def test_empty_publickey
      errors = @contract.call(@valid.merge(publickey: '')).errors

      assert_false(errors.empty?)
    end

    def test_ssrf_guard_localhost
      errors = @contract.call(@valid.merge(endpoint: 'https://localhost:6379/')).errors

      assert_false(errors.empty?)
    end

    def test_ssrf_guard_ipv4_literal
      errors = @contract.call(@valid.merge(endpoint: 'https://127.0.0.1/')).errors

      assert_false(errors.empty?)
    end

    def test_ssrf_guard_ipv6_literal
      errors = @contract.call(@valid.merge(endpoint: 'https://[::1]/')).errors

      assert_false(errors.empty?)
    end

    def test_ssrf_guard_no_tld
      errors = @contract.call(@valid.merge(endpoint: 'https://internal/push')).errors

      assert_false(errors.empty?)
    end

    def test_ssrf_guard_reserved_tld
      errors = @contract.call(@valid.merge(endpoint: 'https://server.local/push')).errors

      assert_false(errors.empty?)
    end

    def test_public_http_uri_accepts_example_com
      assert_true(SwSubscriptionContract.public_http_uri?('https://example.com/push'))
    end

    def test_public_http_uri_rejects_http
      assert_false(SwSubscriptionContract.public_http_uri?('http://example.com/push'))
    end

    def test_public_http_uri_rejects_localhost
      assert_false(SwSubscriptionContract.public_http_uri?('https://localhost/'))
    end

    def test_allowed_host_passes_when_list_empty
      with_allowed_hosts([]) do
        assert_true(SwSubscriptionContract.allowed_host?('https://example.com/push'))
      end
    end

    def test_allowed_host_blocks_unlisted_host
      with_allowed_hosts(['relay.capsicum.example']) do
        assert_false(SwSubscriptionContract.allowed_host?('https://example.com/push'))
      end
    end

    def test_allowed_host_passes_for_listed_host
      with_allowed_hosts(['relay.capsicum.example']) do
        assert_true(SwSubscriptionContract.allowed_host?('https://relay.capsicum.example/push'))
      end
    end

    def test_allowed_host_case_insensitive
      with_allowed_hosts(['Relay.Capsicum.Example']) do
        assert_true(SwSubscriptionContract.allowed_host?('https://relay.capsicum.example/push'))
      end
    end

    private

    def with_allowed_hosts(hosts)
      key = '/misskey/sw_subscription/allowed_hosts'
      original = Config.instance[key]
      Config.instance[key] = hosts
      yield
    ensure
      Config.instance[key] = original
    end
  end
end
