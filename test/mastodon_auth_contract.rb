module Mulukhiya
  class MastodonAuthContractTest < TestCase
    def setup
      @contract = MastodonAuthContract.new
    end

    def test_call
      errors = @contract.call(code: 'hoge').errors
      assert_empty(errors)

      errors = @contract.call(code: nil).errors
      assert_false(errors.empty?)
    end
  end
end
