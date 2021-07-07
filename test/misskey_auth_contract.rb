module Mulukhiya
  class MisskeyAuthContractTest < TestCase
    def setup
      @contract = MisskeyAuthContract.new
    end

    def test_call
      errors = @contract.call(code: 'hoge').errors
      assert(errors.empty?)

      errors = @contract.call(code: nil).errors
      assert_false(errors.empty?)
    end
  end
end
