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
      # JSON を返す。harness は SNS 本体をパスするだけで mulukhiya の webhook ルートを
      # 提供しないため、応答の形が **系によって二通り**になる (#4492):
      #   - Mastodon: 前段の nginx が HTML のエラーページを返す
      #   - Misskey: nginx を挟まないので Misskey (Fastify) が 404 の JSON 包絡を返す
      # どちらも同じ「エンドポイント未提供」なので、harness 駆動時のみ明示 omit する
      # （silent skip ではない）。非 harness で同じものが返るのは実退行なので、下の
      # JSON.parse / assert で落とす。harness 側の provisioning は chubo2#63。
      omit('mulukhiya webhook エンドポイント未提供（chubo2#63）') \
        if harness? && endpoint_missing?(command.stdout)

      assert_predicate(command.status, :zero?)
      status = JSON.parse(command.stdout)

      assert_kind_of(Hash, status)
      assert_includes(['id', 'account', 'createdNote'], status.keys.first)
    end

    private

    # harness が mulukhiya の webhook ルートを提供していないことの検出。
    # ⚠ 「JSON が返らなかった」で広く倒すと実退行まで飲むので、**HTML エラーページ**と
    # **Fastify の 404 包絡**（`{"message":..., "error":"Not Found", "statusCode":404}`）に
    # 限定する。それ以外の応答は omit せず assert で落とす。
    def endpoint_missing?(body)
      return true if body.lstrip.start_with?('<')
      parsed = JSON.parse(body) rescue nil
      return false unless parsed.is_a?(Hash)
      return parsed['statusCode'] == 404
    end
  end
end
