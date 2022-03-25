module Mulukhiya
  class NextcloudClippingCommandContractTest < TestCase
    def setup
      @contract = NextcloudClippingCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'nextcloud_clipping', url: 'https://mstdn.example.com/web/statuses/111').errors
      assert_empty(errors)

      errors = @contract.call(command: 'test').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'nextcloud', url: 'https://mstdn.example.com/web/statuses/111').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'nextcloud_clipping', url: 'hoge').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'nextcloud_clipping', url: 1111).errors
      assert_false(errors.empty?)
    end
  end
end
