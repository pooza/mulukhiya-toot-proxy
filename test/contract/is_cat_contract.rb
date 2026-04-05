module Mulukhiya
  class IsCatContractTest < TestCase
    def setup
      @contract = IsCatContract.new
    end

    def test_call
      errors = @contract.call({}).errors

      assert_false(errors.empty?)

      errors = @contract.call(accts: ['user@example.com']).errors

      assert_empty(errors)

      errors = @contract.call(accts: ['user@example.com', 'user2@example.com']).errors

      assert_empty(errors)

      errors = @contract.call(accts: [123]).errors

      assert_false(errors.empty?)
    end
  end
end
