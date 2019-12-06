module MulukhiyaTootProxy
  class AccountTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @config = Config.instance
      @account = Account.get(token: @config['/test/token'])
    end

    def test_config
      return if Environment.ci?
      assert(@account.config.is_a?(Hash))
    end

    def test_webhook
      return if Environment.ci?
      assert(@account.webhook.is_a?(Webhook))
    end

    def test_slack
      return if Environment.ci?
      assert(@account.slack.is_a?(Slack))
    end

    def test_growi
      return if Environment.ci?
      assert(@account.growi.is_a?(GrowiClipper))
    end

    def test_dropbox
      return if Environment.ci?
      assert(@account.dropbox.is_a?(DropboxClipper))
    end

    def test_disable?
      return if Environment.ci?
      @config['/handler/pre_toot'].each do |v|
        assert(@account.disable?(v).is_a?(TrueClass) || @account.disable?(v).is_a?(FalseClass))
      end
    end
  end
end
