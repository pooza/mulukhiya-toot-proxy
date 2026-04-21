module Mulukhiya
  class SwSubscriptionContractTest < TestCase
    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def setup
      @contract = SwSubscriptionContract.new
      @valid = {
        endpoint: 'https://relay.example.com/push/token',
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
  end
end
