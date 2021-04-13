module Mulukhiya
  class GrowiClippingCommandContractTest < TestCase
    def setup
      @contract = GrowiClippingCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'growi_clipping', url: 'https://mstdn.example.com/web/statuses/111').errors
      assert(errors.empty?)

      errors = @contract.call(command: 'test').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'growi', url: 'https://mstdn.example.com/web/statuses/111').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'growi_clipping', url: 'hoge').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'growi_clipping', url: 1111).errors
      assert_false(errors.empty?)
    end
  end
end
