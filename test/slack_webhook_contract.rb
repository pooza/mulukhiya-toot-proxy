module Mulukhiya
  class SlackWebhookContractTest < TestCase
    def disable?
      return true unless SlackService.config?
      return super
    end

    def setup
      @contract = SlackWebhookContract.new
    end

    def test_call
      errors = @contract.call(text: 'hoge', digest: 'fuga').errors
      assert_empty(errors)

      errors = @contract.call(text: 11, digest: 'fuga').errors
      assert_false(errors.empty?)

      errors = @contract.call(text: 'hoge', digest: 22).errors
      assert_false(errors.empty?)

      errors = @contract.call(text: nil, digest: 'fuga').errors
      assert_false(errors.empty?)

      errors = @contract.call(text: 'hoge', digest: nil).errors
      assert_false(errors.empty?)

      errors = @contract.call(text: 'hoge').errors
      assert_false(errors.empty?)

      errors = @contract.call(digest: 'fuga').errors
      assert_false(errors.empty?)
    end
  end
end
