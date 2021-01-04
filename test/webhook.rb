module Mulukhiya
  class WebhookTest < TestCase
    def setup
      @test_hook = Environment.test_account.webhook
      @payloads = {
        image: SlackWebhookPayload.new(
          'text' => 'ハミガキと言われてキレたのは面白かったですw',
          'attachments' => [
            {'image_url' => 'https://uzakichan.com/_img/sns_img.jpg'},
          ],
        ),
        spoiler: SlackWebhookPayload.new(
          'text' => '犯人はヤス',
          'spoiler_text' => 'ネタバレあり',
        ),
        blocks: SlackWebhookPayload.new(
          'blocks' => [
            {'type' => 'header', 'text' => {'text' => 'ネタバレ注意2'}},
            {'type' => 'section', 'text' => {'text' => 'こりは何くる？'}},
            {'type' => 'image', 'image_url' => 'https://images-na.ssl-images-amazon.com/images/I/71KPGeyC85L._AC_SL1500_.jpg'},
          ],
        ),
        github: GitHubWebhookPayload.new(zen: 'ニンニク入れますか。'),
      }
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

    def test_post
      assert_kind_of(Reporter, @test_hook.post(@payloads[:image]))
      assert_kind_of(Reporter, @test_hook.post(@payloads[:spoiler]))
      assert_kind_of(Reporter, @test_hook.post(@payloads[:blocks]))
      assert_kind_of(Reporter, @test_hook.post(@payloads[:github]))
    end

    def test_command
      command = @test_hook.command
      command.exec
      assert(command.status.zero?)
      status = JSON.parse(command.stdout)
      assert_kind_of(Hash, status)
      assert(['id', 'account', 'createdNote'].member?(status.keys.first))
    end
  end
end
