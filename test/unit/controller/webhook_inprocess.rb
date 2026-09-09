require 'rack/test'

module Mulukhiya
  # webhook 投稿の full path をインプロセスで検証する (#4428)。
  #
  # ⚠⚠ **harness には前段の mulukhiya が居ない。**`Webhook#uri` は
  # `sns.create_uri("/mulukhiya/webhook/<digest>")` ＝ **プロキシ自身のパス**を
  # 組み立てるので、`WebhookTest#test_command` の curl は**バニラ upstream を
  # 直接叩いて**しまう（Mastodon は nginx の HTML、Misskey は Fastify の 404 JSON）。
  # そのため **webhook だけが harness の検証盲点**になっていた（chubo2#63）。
  #
  # 🔴 **puma を別に立てず、受信コントローラをインプロセスで駆動する。**
  # `/mulukhiya/webhook/<digest>` の受信 → `pre_toot` パイプライン →
  # `sns.post` で upstream へ実投稿、までを 1 プロセスで通す。
  #
  # ⚠ `Webhook#command`（curl スニペット）は tomato-shrieker 連携で使うので
  # **変更しない**。テスト側の検証手段だけをインプロセス化する。
  class WebhookInprocessTest < TestCase
    include Rack::Test::Methods

    def disable?
      return true unless Environment.dbms_class&.config?
      return true unless controller_class.webhook?
      return true unless account&.webhook
      return super
    rescue StandardError
      return true
    end

    # ⚠ `Rack::URLMap` の外で直接叩くので、パスは**マウント相対**（`/<digest>`）。
    def app = WebhookController

    def setup
      return if disable?
      # ⚠⚠ **harness のアカウントは webhook トークンを持たない。**`Webhook#digest` は
      # トークン未設定で `ConfigError` を投げる（#4487 で入れた、幽霊 webhook URL を
      # 作らせないためのガード）ので、**実際に webhook を有効化した状態を作る**。
      # ⚠ ここは harness の provisioning が用意しない部分（chubo2#63）。
      @original_token = account.user_config.token
      account.user_config.token = account_class.test_token
      # ⚠ **トークンを入れてから取る。**`Webhook#initialize` が `@sns.token` を
      # そのとき固定するので、先に取ると空のまま握ることになる。
      @hook = account.webhook
    end

    def teardown
      super
      return if disable?
      # ⚠ 他のテストが同じアカウントを見るので、必ず戻す。
      account.user_config.token = @original_token if @original_token
    end

    # 🔴 **本体。**受信からパイプラインを通って upstream へ実投稿されること。
    def test_post_reaches_upstream
      post_webhook({'text' => "#{Package.name} webhook inprocess test"})

      assert_equal(200, last_response.status, last_response.body.to_s[0, 200])
      body = JSON.parse(last_response.body)
      # ⚠ Mastodon は `id` / `account`、Misskey は `createdNote`。
      assert_includes(['id', 'account', 'createdNote'], body.keys.first)
    end

    # ⚠ **GET は疎通確認だけ。**投稿はしない。
    def test_get_is_a_liveness_check
      get("/#{@hook.digest}", {}, rack_env)

      assert_equal(200, last_response.status)
      assert_equal('OK', JSON.parse(last_response.body)['message'])
    end

    # 🔴 **知らない digest は 404。**⚠ 本文の形も押さえる（#4520 で
    # `not_found` がルート由来のボディを潰さなくなった）。
    def test_unknown_digest_is_not_found
      post("/#{'0' * 64}", '{"text":"x"}', rack_env)

      assert_equal(404, last_response.status)
      assert_predicate(JSON.parse(last_response.body), :present?)
    end

    # ⚠ 契約違反は 422。`text` も `blocks` も無いペイロード。
    def test_invalid_payload_is_unprocessable
      post_webhook({'unknown_key' => 'x'})

      assert_equal(422, last_response.status)
    end

    private

    def post_webhook(payload)
      body = payload.to_json
      post("/#{@hook.digest}", body, rack_env(body))
    end

    # ⚠ **`CONTENT_TYPE` を明示しないと body が届かない。**form-urlencoded だと
    # Rack が params 解釈で `rack.input` を読み切ってしまい、`before` の
    # `request.body.read` が空文字を返す（本番の Puma では起きないテスト固有の事情）。
    # ⚠ Sinatra のホスト認可で 403 になるので `HTTP_HOST` も要る。
    def rack_env(body = '')
      return {
        'HTTP_HOST' => 'localhost',
        'CONTENT_TYPE' => 'application/json',
        'rack.input' => StringIO.new(body),
      }
    end
  end
end
