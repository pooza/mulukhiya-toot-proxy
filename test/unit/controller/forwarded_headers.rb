module Mulukhiya
  # 上流へ中継する受信ヘッダの許可リスト (#4598)。
  #
  # ⚠ **`Idempotency-Key` はモロヘイヤを通ると消えていた。**プロキシ経路
  # (`POST /api/:version/statuses`) も Slack 互換 webhook もヘッダを渡しておらず、
  # クライアントが正しくキーを付けていても上流の畳み込みが働かない＝応答だけ
  # 失われたときの再送が二重投稿になっていた。
  class ForwardedHeadersTest < TestCase
    KEY = 'Idempotency-Key'.freeze

    def test_forwards_idempotency_key
      assert_equal(expected(KEY => 'abc123'), forwarded(KEY => 'abc123'))
    end

    # ⚠ **丸投げしない。**Host / Content-Length / Cookie / X-Mulukhiya /
    # Authorization を上流へ中継すると、経路の識別やトークンの扱いが壊れる。
    def test_drops_everything_else
      headers = {
        'Authorization' => 'Bearer secret',
        'Cookie' => 'session=1',
        'Host' => 'mstdn.example.com',
        'Content-Length' => '42',
        'X-Mulukhiya' => 'true',
        'User-Agent' => 'capsicum',
      }

      assert_empty(forwarded(headers))
    end

    def test_keeps_only_the_allowed_header
      headers = {KEY => 'abc123', 'Cookie' => 'session=1', 'X-Mulukhiya' => 'true'}

      assert_equal(expected(KEY => 'abc123'), forwarded(headers))
    end

    # ⚠ **モロヘイヤ側で生成しない。**本文のハッシュ等から自前で作ると、実況で
    # 意図的に連投される同一本文を上流が畳んで投稿が黙って消える。
    def test_does_not_generate_key
      assert_empty(forwarded({}))
      assert_empty(forwarded('User-Agent' => 'capsicum'))
    end

    # ⚠ **Idempotency-Key は Mastodon API の仕様。**Misskey には相当物が無いので
    # 送らない（送っても無害だが「効いているつもり」を作らない）。
    def test_forwards_only_on_mastodon
      forwarded = forwarded(KEY => 'abc123')

      if controller_class.name == 'mastodon'
        assert_equal({KEY => 'abc123'}, forwarded)
      else
        assert_empty(forwarded)
      end
    end

    # webhook 経路も同じ許可リストを通す。⚠ 引数が省略可能でないと、
    # AnnictService の `webhook.post(payload)` が壊れる。
    def test_webhook_post_accepts_forwarded_headers
      assert_equal([[:req, :payload], [:opt, :params]], Webhook.instance_method(:post).parameters)
    end

    private

    # Mastodon 以外の環境では常に空になる。
    def expected(headers)
      return controller_class.name == 'mastodon' ? headers : {}
    end

    def forwarded(headers)
      controller = MastodonController.new!
      controller.instance_variable_set(:@headers, headers)
      return controller.forwarded_headers
    end
  end
end
