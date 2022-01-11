module Mulukhiya
  class AccountTest < TestCase
    test 'テスト用アカウントの有無' do
      assert_not_nil(account)
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

    def test_info?
      return unless account
      assert_boolean(account.info?)
    end

    def test_default_scopes
      return unless account
      assert_kind_of(Set, account.default_scopes)
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

    def test_lemmy
      return unless account&.lemmy
      assert_kind_of(LemmyClipper, account.lemmy)
    end

    def test_nextcloud
      return unless account&.nextcloud
      assert_kind_of(NextcloudClipper, account.nextcloud)
    end

    def test_disable?
      return unless account
      Event.new(:pre_toot).handlers do |handler|
        assert_boolean(account.disable?(handler))
      end
    end

    def test_user_tags
      return unless account
      assert_kind_of(TagContainer, account.user_tags)
    end

    def test_disabled_tags
      return unless account
      assert_kind_of(TagContainer, account.disabled_tags)
    end

    def test_featured_tags
      return unless account
      assert_kind_of(TagContainer, account.featured_tags)
    end

    def test_field_tags
      return unless account
      assert_kind_of(TagContainer, account.field_tags)
    end

    def test_bio_tags
      return unless account
      assert_kind_of(TagContainer, account.bio_tags)
    end

    def test_test_account
      assert_kind_of(account_class, account_class.test_account)
      config['/agent/test/token'] = 'aaa'
      assert_nil(account_class.test_account)
    end

    def test_info_account
      assert_kind_of(account_class, account_class.info_account)
      config['/agent/info/token'] = 'bbb'
      assert_nil(account_class.info_account)
    end
  end
end
