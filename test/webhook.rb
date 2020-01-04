module MulukhiyaTootProxy
  class WebhookTest < TestCase
    def setup
      @account = Environment.test_account
    end

    def test_all
      return unless @account.webhook
      Webhook.all do |hook|
        assert_kind_of(Webhook, hook)
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
        assert_kind_of([MastodonService, DolphinService], hook.sns)
      end
    end

    def test_uri
      return unless @account.webhook
      Webhook.all do |hook|
        assert_kind_of(Ginseng::URI, hook.uri)
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
