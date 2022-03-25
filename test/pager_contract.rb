module Mulukhiya
  class PagerContractTest < TestCase
    def setup
      @contract = PagerContract.new
    end

    def test_call
      errors = @contract.call({}).errors
      assert_empty(errors)

      errors = @contract.call(page: 0).errors
      assert_false(errors.empty?)

      errors = @contract.call(page: 1).errors
      assert_empty(errors)

      errors = @contract.call(page: 2).errors
      assert_empty(errors)
    end
  end
end
