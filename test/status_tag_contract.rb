module Mulukhiya
  class StatusTagContractTest < TestCase
    def setup
      @contract = StatusTagContract.new
    end

    def test_call
      errors = @contract.call({}).errors
      assert_false(errors.empty?)

      errors = @contract.call(id: 'zxxxxx').errors
      assert_false(errors.empty?)

      errors = @contract.call(tag: 'delmulin').errors
      assert_false(errors.empty?)

      errors = @contract.call(id: 'aaaaaaacdfg', tag: 'precure_fun').errors
      assert(errors.empty?)
    end
  end
end
