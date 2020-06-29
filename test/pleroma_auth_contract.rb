module Mulukhiya
  class PleromaAuthContractTest < TestCase
    def setup
      @contract = PleromaAuthContract.new
    end

    def test_call
      errors = @contract.call(code: 'hoge').errors
      assert(errors.empty?)

      errors = @contract.call(code: nil).errors
      assert_false(errors.empty?)
    end
  end
end
