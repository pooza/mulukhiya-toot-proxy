module Mulukhiya
  class WebhookTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return true unless controller_class.webhook?
      return true unless account.webhook rescue nil
      return super
    end

    def setup
      return if disable?
      @test_hook = account.webhook
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
        assert_predicate(hook.digest, :present?)
      end
    end

    def test_visibility
      Webhook.all do |hook|
        assert_includes(parser_class.visibility_names.values, hook.visibility)
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
        assert_predicate(hook.uri, :absolute?)
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
    end

    def test_command
      command = @test_hook.command
      command.exec

      # webhook エンドポイント（/mulukhiya/webhook/<digest>）は mulukhiya アプリが処理して
      # JSON を返す。harness の proxy は nginx→Mastodon をパスするのみで mulukhiya webhook
      # ルートを提供しないため HTML(エラーページ)が返る。harness 駆動時のみ明示 omit する
      # （silent skip ではない）。非 harness で HTML が返るのは実退行なので下の JSON.parse で
      # 落とす。harness 側の provisioning は chubo2#63。
      omit('mulukhiya webhook エンドポイント未提供（HTML 応答・chubo2#63）') \
        if harness? && command.stdout.lstrip.start_with?('<')

      assert_predicate(command.status, :zero?)
      status = JSON.parse(command.stdout)

      assert_kind_of(Hash, status)
      assert_includes(['id', 'account', 'createdNote'], status.keys.first)
    end
  end
end
