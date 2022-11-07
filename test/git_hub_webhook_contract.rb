module Mulukhiya
  class GitHubWebhookContractTest < TestCase
    def disable?
      return true unless controller_class.webhook?
      return true unless (account.webhook rescue nil)
      return super
    end

    def setup
      @contract = GitHubWebhookContract.new
    end

    def test_call
      errors = @contract.call(digest: 'fuga').errors

      assert_empty(errors)

      errors = @contract.call(digest: 11).errors

      assert_false(errors.empty?)

      errors = @contract.call(digest: nil).errors

      assert_false(errors.empty?)

      errors = @contract.call({}).errors

      assert_false(errors.empty?)
    end
  end
end
