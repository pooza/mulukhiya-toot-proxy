module Mulukhiya
  class SpotifyAuthContractTest < TestCase
    def setup
      @contract = SpotifyAuthContract.new
    end

    def test_call
      # ユーザー特定は bearer 認証で行うため token は不要。
      # ⚠ `state` は 5.37.0 (#4414) から必須（CSRF 対策）。
      errors = @contract.call(code: 'auth-code', state: 'the-state').errors

      assert_empty(errors)

      errors = @contract.call(code: nil).errors

      assert_false(errors.empty?)

      errors = @contract.call({}).errors

      assert_false(errors.empty?)
    end
  end
end
