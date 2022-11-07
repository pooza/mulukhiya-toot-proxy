module Mulukhiya
  class FilterCommandContractTest < TestCase
    def disable?
      return true unless controller_class.filter?
      return super
    end

    def setup
      @contract = FilterCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'filter', phrase: 'うんこ').errors

      assert_empty(errors)

      errors = @contract.call(command: 'filter', tag: 'うんこ', action: 'register').errors

      assert_empty(errors)

      errors = @contract.call(command: 'f', phrase: 'うんこ').errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'filter').errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'filter', tag: 'うんこ', action: 'hoge').errors

      assert_false(errors.empty?)
    end
  end
end
