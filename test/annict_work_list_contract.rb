module Mulukhiya
  class AnnictWorkListContractTest < TestCase
    def setup
      @contract = StatusListContract.new
    end

    def test_call
      errors = @contract.call({}).errors

      assert_empty(errors)

      errors = @contract.call(q: 0).errors

      assert_false(errors.empty?)

      errors = @contract.call(q: 'キュアホワイトうどん').errors

      assert_empty(errors)
    end
  end
end
