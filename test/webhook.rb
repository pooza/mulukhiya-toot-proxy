module Mulukhiya
  class WebhookTest < TestCase
    def setup
      @test_hook = Environment.test_account.webhook
    end

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

    def test_visibility
      Webhook.all do |hook|
        assert(Environment.parser_class.visibility_names.values.member?(hook.visibility))
      end
    end

    def test_sns
      Webhook.all do |hook|
        assert_kind_of(Ginseng::Fediverse::Service, hook.sns)
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

    def test_command
      command = @test_hook.command
      command.exec
      assert(command.status.zero?)
      status = JSON.parse(command.stdout)
      assert_kind_of(Hash, status)
      assert(['id', 'createdNote'].member?(status.keys.first))
    end
  end
end
