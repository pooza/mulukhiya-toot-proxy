module Mulukhiya
  class MisskeyAuthContractTest < TestCase
    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def setup
      @contract = MisskeyAuthContract.new
    end

    def test_call
      errors = @contract.call(code: 'hoge').errors
      assert_empty(errors)

      errors = @contract.call(code: nil).errors
      assert_false(errors.empty?)
    end
  end
end
