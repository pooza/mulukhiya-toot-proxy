module MulukhiyaTootProxy
  class WebhookTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
    end

    def test_all
      Webhook.all do |hook|
        assert(hook.is_a?(Webhook))
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

    def test_mastodon
      Webhook.all do |hook|
        assert(hook.mastodon.is_a?(Mastodon))
      end
    end

    def test_uri
      Webhook.all do |hook|
        assert(hook.uri.is_a?(Addressable::URI))
      end
    end

    def test_toot_tags
      Webhook.all do |hook|
        assert(hook.toot_tags.is_a?(Array))
      end
    end

    def test_to_json
      Webhook.all do |hook|
        assert(hook.to_json.present?)
      end
    end

    def test_toot
      Webhook.owned_all(@config['/test/account']) do |hook|
        assert_equal(hook.toot('木の水晶球').code, 200)
      end
    end
  end
end
