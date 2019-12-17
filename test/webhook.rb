module MulukhiyaTootProxy
  class WebhookTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @account = Environment.account_class.get(token: @config['/test/token'])
    end

    def test_all
      return unless @account.webhook
      Webhook.all do |hook|
        assert(hook.is_a?(Webhook))
      end
    end

    def test_create
      return unless @account.webhook
      Webhook.all do |hook|
        assert_not_nil(Webhook.create(hook.digest))
      end
    end

    def test_digest
      return unless @account.webhook
      Webhook.all do |hook|
        assert(hook.digest.present?)
      end
    end

    def test_sns
      return unless @account.webhook
      Webhook.all do |hook|
        assert(hook.sns.is_a?(MastodonService) || hook.sns.is_a?(DolphinService))
      end
    end

    def test_uri
      return unless @account.webhook
      Webhook.all do |hook|
        assert(hook.uri.is_a?(Ginseng::URI))
      end
    end

    def test_to_json
      return unless @account.webhook
      Webhook.all do |hook|
        assert(hook.to_json.present?)
      end
    end

    def test_toot
      return unless @account.webhook
      hook = Webhook.owned_all(@account.username).to_a.first
      assert_equal(hook.toot('木の水晶球').response.code, 200)
    end
  end
end
