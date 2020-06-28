module Mulukhiya
  class DropboxClippingCommandContractTest < TestCase
    def setup
      @contract = DropboxClippingCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'dropbox_clipping', url: 'https://mstdn.example.com/web/statuses/111').errors
      assert(errors.empty?)

      errors = @contract.call(command: 'test').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'dropbox', url: 'https://mstdn.example.com/web/statuses/111').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'dropbox_clipping', url: 'hoge').errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'dropbox_clipping', url: 1111).errors
      assert_false(errors.empty?)
    end
  end
end
