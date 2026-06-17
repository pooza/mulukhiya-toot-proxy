module Mulukhiya
  class SpotifyAuthContractTest < TestCase
    def setup
      @contract = SpotifyAuthContract.new
    end

    def test_call
      errors = @contract.call(token: 'sns-token', code: 'auth-code').errors

      assert_empty(errors)

      errors = @contract.call(token: 'sns-token', code: nil).errors

      assert_false(errors.empty?)

      errors = @contract.call(code: 'auth-code').errors

      assert_false(errors.empty?)
    end
  end
end
