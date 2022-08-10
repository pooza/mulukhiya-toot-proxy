module Mulukhiya
  class UserTagInitializeWorkerTest < TestCase
    def setup
      @worker = Worker.create(:user_tag_initialize)
      test_account.user_config.update(tagging: {user_tags: ['実況']})
    end

    def test_perform
      assert_equal(['実況'], test_account.user_config['/tagging/user_tags'])
      @worker.perform('account_id' => test_account.id)
      assert_nil(test_account.user_config['/tagging/user_tags'])
    end

    def test_perform_all
      assert_equal(['実況'], test_account.user_config['/tagging/user_tags'])
      @worker.perform
      assert_nil(test_account.user_config['/tagging/user_tags'])
    end
  end
end
