module MulukhiyaTootProxy
  class AccountTest < Test::Unit::TestCase
    def setup
      return unless Postgres.config?
      @config = Config.instance
      @account = Account.get(token: @config['/test/token'])
    end

    def test_config
      return unless Postgres.config?
      assert(@account.config.is_a?(Hash))
    end

    def test_webhook
      return unless Postgres.config?
      assert(@account.webhook.is_a?(Webhook))
    end

    def test_slack
      return unless Postgres.config?
      assert(@account.slack.is_a?(Slack))
    end

    def test_growi
      return unless Postgres.config?
      assert(@account.growi.is_a?(GrowiClipper))
    end

    def test_dropbox
      return unless Postgres.config?
      assert(@account.dropbox.is_a?(DropboxClipper))
    end

    def test_disable?
      return unless Postgres.config?
      @config['/handler/pre_toot'].each do |v|
        assert(@account.disable?(v).is_a?(TrueClass) || @account.disable?(v).is_a?(FalseClass))
      end
    end
  end
end
