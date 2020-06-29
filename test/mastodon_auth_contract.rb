module Mulukhiya
  class MastodonAuthContractTest < TestCase
    def setup
      @contract = MastodonAuthContract.new
    end

    def test_call
      errors = @contract.call(code: 'hoge').errors
      assert(errors.empty?)

      errors = @contract.call(code: nil).errors
      assert_false(errors.empty?)
    end
  end
end
