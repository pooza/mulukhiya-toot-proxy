module Mulukhiya
  class LemmyClippingCommandContractTest < TestCase
    def disable?
      return true unless controller_class.lemmy?
      return true unless account.lemmy.login rescue nil
      return super
    end

    def setup
      @contract = LemmyClippingCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'lemmy_clipping', url: 'https://mstdn.example.com/web/statuses/111').errors

      assert_empty(errors)

      errors = @contract.call(command: 'test').errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'lemmy', url: 'https://mstdn.example.com/web/statuses/111').errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'lemmy_clipping', url: 'hoge').errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'lemmy_clipping', url: 1111).errors

      assert_false(errors.empty?)
    end
  end
end
