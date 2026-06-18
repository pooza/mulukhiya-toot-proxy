module Mulukhiya
  class SpotifyAuthContractTest < TestCase
    def setup
      @contract = SpotifyAuthContract.new
    end

    def test_call
      # ユーザー特定は bearer 認証で行うため code のみ必須・token は不要。
      errors = @contract.call(code: 'auth-code').errors

      assert_empty(errors)

      errors = @contract.call(code: nil).errors

      assert_false(errors.empty?)

      errors = @contract.call({}).errors

      assert_false(errors.empty?)
    end
  end
end
