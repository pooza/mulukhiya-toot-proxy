module Mulukhiya
  class AccountTest < TestCase
    test 'テスト用アカウントの有無' do
      assert(account)
    end

    def test_get
      return unless account
      assert_equal(account_class.get(token: account.token).id, account.id)
      assert_equal(account_class.get(acct: account.acct.to_s).id, account.id)
      assert_equal(account_class.get(id: account.id).id, account.id)
      assert_nil(account_class.get(token: nil))
    end

    def test_acct
      return unless account
      assert_kind_of(Acct, account.acct)
      assert(account.acct.host.present?)
      assert(account.acct.username.present?)
    end

    def test_to_h
      return unless account
      assert_kind_of(Hash, account.to_h)
    end

    def test_username
      return unless account
      assert_kind_of(String, account.username)
    end

    def test_host
      return unless account
      assert_kind_of(String, account.host)
    end

    def test_domain
      return unless account
      assert_kind_of(String, account.domain)
    end

    def test_display_name
      return unless account
      assert_kind_of(String, account.display_name)
    end

    def test_fields
      return unless account
      assert_kind_of(Array, account.fields)
    end

    def test_bio
      return unless account
      assert_kind_of(String, account.bio)
    end

    def test_operator?
      return unless account
      assert_boolean(account.operator?)
    end

    def test_admin?
      return unless account
      assert_boolean(account.admin?)
    end

    def test_moderator?
      return unless account
      assert_boolean(account.moderator?)
    end

    def test_test?
      return unless account
      assert(account.test?)
    end

    def test_locked?
      return unless account
      assert_boolean(account.locked?)
    end

    def test_notify_verbose?
      return unless account
      assert_boolean(account.notify_verbose?)
    end

    def test_config
      return unless account
      assert_kind_of(UserConfig, account.user_config)
    end

    def test_webhook
      return unless account&.webhook
      assert_kind_of(Webhook, account.webhook)
    end

    def test_growi
      return unless account&.growi
      assert_kind_of(GrowiClipper, account.growi)
    end

    def test_dropbox
      return unless account&.dropbox
      assert_kind_of(DropboxClipper, account.dropbox)
    end

    def test_disable?
      return unless account
      Event.new(:pre_toot).handlers do |handler|
        assert_boolean(account.disable?(handler))
      end
    end

    def test_user_tag_bases
      return unless account
      assert_kind_of(Array, account.user_tag_bases)
    end

    def test_disabled_tag_bases
      return unless account
      assert_kind_of(Array, account.disabled_tag_bases)
    end

    def test_featured_tag_bases
      return unless account
      assert_kind_of(Array, account.featured_tag_bases)
    end

    def test_field_tag_bases
      return unless account
      assert_kind_of(Array, account.field_tag_bases)
    end

    def test_bio_tag_bases
      return unless account
      assert_kind_of(Array, account.bio_tag_bases)
    end
  end
end
