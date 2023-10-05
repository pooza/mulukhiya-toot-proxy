module Mulukhiya
  class AccountTest < TestCase
    def disable?
      return true unless account
      return super
    end

    def test_get
      assert_equal(account_class.get(token: account.token).id, account.id)
      assert_equal(account_class.get(acct: account.acct.to_s).id, account.id)
      assert_equal(account_class.get(id: account.id).id, account.id)
      assert_nil(account_class.get(token: nil))
    end

    def test_acct
      assert_kind_of(Acct, account.acct)
      assert_predicate(account.acct.host, :present?)
      assert_predicate(account.acct.username, :present?)
    end

    def test_to_h
      h = account.to_h

      assert_kind_of(Hash, h)
      assert_kind_of(String, h[:acct])
      assert_kind_of(String, h[:display_name])
      assert_boolean(h[:is_admin])
      assert_boolean(h[:is_info_bot])
      assert_boolean(h[:is_test_bot])
      assert_kind_of(String, h[:url])
      assert_kind_of(String, h[:username])
    end

    def test_uri
      assert_kind_of(Ginseng::URI, account.uri)
      assert_predicate(account.uri, :absolute?)
    end

    def test_username
      assert_kind_of(String, account.username)
    end

    def test_host
      assert_kind_of(String, account.host)
    end

    def test_domain
      assert_kind_of(String, account.domain)
    end

    def test_display_name
      assert_kind_of(String, account.display_name)
    end

    def test_fields
      assert_kind_of(Array, account.fields)
    end

    def test_bio
      assert_kind_of(String, account.bio)
    end

    def test_admin?
      assert_boolean(account.admin?)
    end

    def test_test?
      assert_predicate(account, :test?)
    end

    def test_info?
      assert_boolean(account.info?)
    end

    def test_default_scopes
      assert_kind_of(Set, account.default_scopes)
    end

    def test_locked?
      assert_boolean(account.locked?)
    end

    def test_notify_verbose?
      assert_boolean(account.notify_verbose?)
    end

    def test_config
      assert_kind_of(UserConfig, account.user_config)
    end

    def test_webhook
      assert_kind_of([Webhook, NilClass], account.webhook)
    end

    def test_growi
      assert_kind_of([GrowiClipper, NilClass], account.growi)
    end

    def test_lemmy
      assert_kind_of([LemmyClipper, NilClass], account.lemmy)
    end

    def test_nextcloud
      assert_kind_of([NextcloudClipper, NilClass], account.nextcloud)
    end

    def test_disable?
      Event.new(:pre_toot).handlers do |handler|
        assert_boolean(account.disable?(handler))
      end
    end

    def test_user_tags
      assert_kind_of(TagContainer, account.user_tags)
    end

    def test_disabled_tags
      assert_kind_of(TagContainer, account.disabled_tags)
    end

    def test_featured_tags
      assert_kind_of(TagContainer, account.featured_tags)
    end

    def test_followed_tags
      assert_kind_of(TagContainer, account.followed_tags)
    end

    def test_field_tags
      assert_kind_of(TagContainer, account.field_tags)
    end

    def test_bio_tags
      assert_kind_of(TagContainer, account.bio_tags)
    end

    def test_statuses
      return unless controller_class.account_timeline?

      assert_kind_of(Array, statuses = account.statuses)
      statuses.first(10).each do |status|
        assert_kind_of(Hash, status)
        assert_kind_of(String, status[:created_at])
        assert_kind_of(Time, Time.parse(status[:created_at]))
        assert_kind_of(String, status[:body])
        assert_kind_of(String, status[:footer])
        assert_kind_of(Array, status[:footer_tags])
        status[:footer_tags].each do |tag|
          assert_kind_of(Hash, tag)
          assert_boolean(tag[:is_deletable])
          assert_boolean(tag[:is_default])
        end

        assert_boolean(status[:is_taggable])
      end
    end

    def test_test_account
      assert_kind_of(account_class, account_class.test_account)
      config['/agent/test/token'] = 'aaa'

      assert_nil(account_class.test_account)
    end

    def test_recent_status
      assert_kind_of(status_class, test_account.recent_status)
    end

    def test_info_account
      assert_kind_of(account_class, account_class.info_account)
      config['/agent/info/token'] = 'bbb'

      assert_nil(account_class.info_account)
    end
  end
end
