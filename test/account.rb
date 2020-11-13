module Mulukhiya
  class AccountTest < TestCase
    def setup
      @account = Environment.test_account
    end

    def test_get
      assert_equal(Environment.account_class.get(token: @account.token).id, @account.id)
      assert_equal(Environment.account_class.get(acct: @account.acct.to_s).id, @account.id)
      assert_equal(Environment.account_class.get(id: @account.id).id, @account.id)
      assert_nil(Environment.account_class.get(token: nil))
    end

    def test_acct
      assert_kind_of(Acct, @account.acct)
      assert(@account.acct.host.present?)
      assert(@account.acct.username.present?)
    end

    def test_to_h
      assert_kind_of(Hash, @account.to_h)
    end

    def test_admin?
      assert_boolean(@account.admin?)
    end

    def test_moderator?
      assert_boolean(@account.moderator?)
    end

    def test_locked?
      assert_boolean(@account.locked?)
    end

    def test_notify_verbose?
      assert_boolean(@account.notify_verbose?)
    end

    def test_config
      assert_kind_of(UserConfig, @account.config)
    end

    def test_webhook
      return unless @account.webhook
      assert_kind_of(Webhook, @account.webhook)
    end

    def test_growi
      return unless @account.growi
      assert_kind_of(GrowiClipper, @account.growi)
    end

    def test_dropbox
      return unless @account.dropbox
      assert_kind_of(DropboxClipper, @account.dropbox)
    end

    def test_tags
      assert_kind_of(Array, @account.tags)
    end
  end
end
