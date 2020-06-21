module Mulukhiya
  class WebhookTest < TestCase
    def test_all
      Webhook.all do |hook|
        assert_kind_of(Webhook, hook)
      end
    end

    def test_create
      Webhook.all do |hook|
        assert_kind_of([Webhook, NilClass], Webhook.create(hook.digest))
      end
    end

    def test_digest
      Webhook.all do |hook|
        assert(hook.digest.present?)
      end
    end

    def test_sha1_digest
      Webhook.all do |hook|
        assert(hook.sha1_digest.present?)
      end
    end

    def test_sns
      Webhook.all do |hook|
        assert_kind_of([MastodonService, MisskeyService, PleromaService], hook.sns)
      end
    end

    def test_uri
      Webhook.all do |hook|
        assert_kind_of(Ginseng::URI, hook.uri)
      end
    end

    def test_to_json
      Webhook.all do |hook|
        assert_kind_of(Hash, JSON.parse(hook.to_json))
      end
    end
  end
end
