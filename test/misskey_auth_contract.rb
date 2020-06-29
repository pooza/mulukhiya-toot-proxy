module Mulukhiya
  class MisskeyAuthContractTest < TestCase
    def setup
      @contract = MisskeyAuthContract.new
    end

    def test_call
      errors = @contract.call(token: 'hoge').errors
      assert(errors.empty?)

      errors = @contract.call(token: nil).errors
      assert_false(errors.empty?)
    end
  end
end
