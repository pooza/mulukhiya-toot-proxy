module Mulukhiya
  class StatusContractTest < TestCase
    def setup
      @contract = StatusContract.new
    end

    def test_call
      errors = @contract.call({}).errors

      assert_false(errors.empty?)

      errors = @contract.call(id: 'zxxxxx').errors

      assert_empty(errors)
    end
  end
end
