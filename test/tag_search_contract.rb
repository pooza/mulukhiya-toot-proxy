module Mulukhiya
  class TagSearchContractTest < TestCase
    def setup
      @contract = TagSearchContract.new
    end

    def test_call
      errors = @contract.call(q: 'hoge').errors
      assert_empty(errors)

      errors = @contract.call(q: nil).errors
      assert_false(errors.empty?)
    end
  end
end
