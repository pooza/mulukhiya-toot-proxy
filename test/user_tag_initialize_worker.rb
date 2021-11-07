module Mulukhiya
  class UserTagInitializeWorkerTest < TestCase
    def setup
      @worker = UserTagInitializeWorker.new
      test_account.user_config.update(tagging: {user_tags: ['実況']})
    end

    def test_all_accounts
      assert_kind_of(Array, @worker.accounts)
      @worker.accounts.each do |account|
        assert_kind_of(account_class, account)
      end
    end

    def test_symbol_account
      assert_kind_of(Array, @worker.accounts(account_id: test_account.id))
      @worker.accounts.each do |account|
        assert_kind_of(account_class, account)
      end
    end

    def test_string_account
      assert_kind_of(Array, @worker.accounts('account_id' => test_account.id))
      @worker.accounts.each do |account|
        assert_kind_of(account_class, account)
      end
    end

    def test_perform
      assert_equal(test_account.user_config['/tagging/user_tags'], ['実況'])
      @worker.perform
      assert_nil(test_account.user_config['/tagging/user_tags'])
    end
  end
end
