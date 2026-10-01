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
      assert_equal({KEY => 'abc123'}, forwarded({KEY => 'abc123'}))
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

      assert_equal({KEY => 'abc123'}, forwarded(headers))
    end

    # ⚠ **モロヘイヤ側で生成しない。**本文のハッシュ等から自前で作ると、実況で
    # 意図的に連投される同一本文を上流が畳んで投稿が黙って消える。
    def test_does_not_generate_key
      assert_empty(forwarded({}))
      assert_empty(forwarded({'User-Agent' => 'capsicum'}))
    end

    # ⚠ **Idempotency-Key は Mastodon API の仕様。**Misskey には相当物が無いので
    # 送らない（送っても無害だが「効いているつもり」を作らない）。
    def test_forwards_on_mastodon
      assert_equal({KEY => 'abc123'}, forwarded({KEY => 'abc123'}, controller: 'mastodon'))
    end

    def test_does_not_forward_on_misskey
      assert_empty(forwarded({KEY => 'abc123'}, controller: 'misskey'))
    end

    # ⚠ **判定は SNS の型で行う (#4635)。**コントローラ名で見ると、専用の
    # コントローラクラスを持たない Mastodon 系（Akkoma・Fedibird）では
    # `controller_class` が nil になって落ちる。Misskey 系も同様。
    def test_forwards_on_mastodon_type
      assert_equal({KEY => 'abc123'}, forwarded({KEY => 'abc123'}, controller: 'akkoma'))
      assert_equal({KEY => 'abc123'}, forwarded({KEY => 'abc123'}, controller: 'fedibird'))
    end

    def test_does_not_forward_on_misskey_type
      assert_empty(forwarded({KEY => 'abc123'}, controller: 'firefish'))
    end

    # webhook 経路も同じ許可リストを通す。⚠ 引数が省略可能でないと、
    # AnnictService の `webhook.post(payload)` が壊れる。
    def test_webhook_post_accepts_forwarded_headers
      assert_equal([[:req, :payload], [:opt, :params]], Webhook.instance_method(:post).parameters)
    end

    private

    # ⚠ **期待値を実装と同じ式で組まない (#4635)。**判定を環境から引くと、
    # テストを走らせた環境の片側しか検証されず、判定式が壊れても両辺が一緒に
    # 壊れて緑のまま残る。環境は差し替えて固定し、期待値はリテラルで書く。
    def forwarded(headers, controller: 'mastodon')
      with_controller(controller) do
        instance = MastodonController.new!
        instance.instance_variable_set(:@headers, headers)
        return instance.forwarded_headers
      end
    end

    def with_controller(name)
      Environment.singleton_class.alias_method(:controller_name_without_stub, :controller_name)
      Environment.define_singleton_method(:controller_name) {name}
      yield
    ensure
      Environment.singleton_class.alias_method(:controller_name, :controller_name_without_stub)
    end
  end
end
