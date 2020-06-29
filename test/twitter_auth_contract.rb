module Mulukhiya
  class TwitterAuthContractTest < TestCase
    def setup
      @contract = TwitterAuthContract.new
    end

    def test_call
      errors = @contract.call(token: 'hoge', oauth_token: 'fuga', oauth_verifier: 'piyo').errors
      assert(errors.empty?)

      errors = @contract.call(token: 'hoge', oauth_token: 'fuga').errors
      assert_false(errors.empty?)

      errors = @contract.call(token: 'hoge', oauth_verifier: 'piyo').errors
      assert_false(errors.empty?)

      errors = @contract.call(oauth_token: 'fuga', oauth_verifier: 'piyo').errors
      assert_false(errors.empty?)

      errors = @contract.call(token: 11, oauth_token: 'fuga', oauth_verifier: 'piyo').errors
      assert_false(errors.empty?)

      errors = @contract.call(token: 'hoge', oauth_token: 22, oauth_verifier: 'piyo').errors
      assert_false(errors.empty?)

      errors = @contract.call(token: 'hoge', oauth_token: 'fuga', oauth_verifier: 33).errors
      assert_false(errors.empty?)
    end
  end
end
