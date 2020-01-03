module MulukhiyaTootProxy
  class AccountTest < TestCase
    def setup
      @config = Config.instance
      @account = Environment.test_account
    end

    def test_config
      assert(@account.config.is_a?(Hash))
    end

    def test_webhook
      return unless @account.webhook
      assert(@account.webhook.is_a?(Webhook))
    end

    def test_slack
      return unless @account.slack
      assert(@account.slack.is_a?(Slack))
    end

    def test_growi
      return unless @account.growi
      assert(@account.growi.is_a?(GrowiClipper))
    end

    def test_dropbox
      return unless @account.dropbox
      assert(@account.dropbox.is_a?(DropboxClipper))
    end

    def test_disable?
      @config['/handler/mastodon/pre_toot'].each do |v|
        assert(@account.disable?(v).is_a?(TrueClass) || @account.disable?(v).is_a?(FalseClass))
      end
    end
  end
end
