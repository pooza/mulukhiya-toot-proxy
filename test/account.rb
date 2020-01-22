module Mulukhiya
  class AccountTest < TestCase
    def setup
      @config = Config.instance
      @account = Environment.test_account
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

    def test_config
      assert_kind_of(Hash, @account.config)
    end

    def test_webhook
      return unless @account.webhook
      assert_kind_of(Webhook, @account.webhook)
    end

    def test_slack
      return unless @account.slack
      assert_kind_of(Slack, @account.slack)
    end

    def test_growi
      return unless @account.growi
      assert_kind_of(GrowiClipper, @account.growi)
    end

    def test_dropbox
      return unless @account.dropbox
      assert_kind_of(DropboxClipper, @account.dropbox)
    end

    def test_disable?
      @config['/handler/mastodon/pre_toot'].each do |v|
        assert_boolean(@account.disable?(v))
      end
    end

    def test_tags
      assert_kind_of(Array, @account.tags)
    end
  end
end
