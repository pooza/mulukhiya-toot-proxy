module Mulukhiya
  class StatusListContractTest < TestCase
    def setup
      @contract = StatusListContract.new
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

      errors = @contract.call(page: 2, self: 'false').errors

      assert_false(errors.empty?)

      errors = @contract.call(page: 2, self: 0).errors

      assert_empty(errors)

      errors = @contract.call(page: 2, self: 1).errors

      assert_empty(errors)

      errors = @contract.call(q: 0).errors

      assert_false(errors.empty?)

      errors = @contract.call(q: 'キュアホワイトうどん').errors

      assert_empty(errors)
    end
  end
end
