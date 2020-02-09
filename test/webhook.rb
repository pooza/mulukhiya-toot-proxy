module Mulukhiya
  class WebhookTest < TestCase
    def setup
      @account = Environment.test_account
    end

    def test_all
      Webhook.all do |hook|
        assert_kind_of(Webhook, hook)
      end
    end

    def test_create
      Webhook.all do |hook|
        assert_not_nil(Webhook.create(hook.digest))
      end
    end

    def test_digest
      Webhook.all do |hook|
        assert(hook.digest.present?)
      end
    end

    def test_sns
      Webhook.all do |hook|
        assert_kind_of([MastodonService, DolphinService], hook.sns)
      end
    end

    def test_uri
      Webhook.all do |hook|
        assert_kind_of(Ginseng::URI, hook.uri)
      end
    end

    def test_to_json
      Webhook.all do |hook|
        assert(hook.to_json.present?)
      end
    end
  end
end
