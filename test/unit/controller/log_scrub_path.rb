module Mulukhiya
  # webhook の digest をログへ平文で残さないこと (#4655)。
  #
  # ⚠⚠ **digest は資格情報そのもの。**`POST /mulukhiya/webhook/<digest>` は
  # digest だけで投稿権限が通る（`verify_webhook!` 以外に認証が無い）。
  # ⚠ **既存の掃討はどれも当たらない** — `mask_url` は `\A<scheme>://` に一致する
  # 値にしか効かず、`SCRUBBED_LOG_PARAMS` はパラメータのキーしか見ず、
  # nginx 側のパターン（#4511）にも当たらない。
  class LogScrubPathTest < TestCase
    # `Webhook.create_digest` は `String#sha256` ＝ 64 桁の 16 進。
    DIGEST = ('a1b2c3d4' * 8).freeze
    DIGEST_PATTERN = /#{DIGEST}/o

    def setup
      @controller = MisskeyController.new!
    end

    def scrub(path)
      return @controller.send(:scrub_log_path, path)
    end

    # 眼目。webhook のパスから digest が消えること。
    def test_scrubs_webhook_digest
      scrubbed = scrub("/mulukhiya/webhook/#{DIGEST}")

      assert_not_match(DIGEST_PATTERN, scrubbed)
      assert_equal('/mulukhiya/webhook/a1b2c3d4a1b2...', scrubbed)
    end

    # ⚠ **突き合わせられる長さは残す。**`verify_webhook!` のエラーメッセージが
    # 先頭 12 文字なので、ログとエラーで同じ形に見えること。
    def test_prefix_length_matches_verify_webhook_message
      assert_equal(12, LogScrubber::LOG_DIGEST_PREFIX_LENGTH)
      assert_match(
        /params\[:digest\]\[0, 12\]/,
        File.read(File.join(Environment.dir, 'app/lib/mulukhiya/controller/webhook_controller.rb')),
      )
    end

    # ⚠⚠ **マウント位置を仮定しない。**`config/route.yaml` で変えられるし、
    # 前後にセグメントが付いても効くこと。
    def test_scrubs_regardless_of_mount_point
      assert_not_match(DIGEST_PATTERN, scrub("/#{DIGEST}"))
      assert_not_match(DIGEST_PATTERN, scrub("/some/where/#{DIGEST}/extra"))
    end

    # digest でないパスは 1 バイトも変えない（ログが役に立たなくなる）。
    def test_keeps_other_paths
      ['/mulukhiya/api/v1/statuses/123', '/nodeinfo/2.0', '/', ''].each do |path|
        assert_equal(path, scrub(path), "#{path} が書き換えられている")
      end
    end

    # 64 桁ちょうどでなければ digest ではない。
    def test_keeps_near_miss_segments
      ['a' * 63, 'a' * 65, "#{'a' * 63}z"].each do |segment|
        assert_equal("/x/#{segment}", scrub("/x/#{segment}"), "#{segment} が丸められている")
      end
    end

    def test_tolerates_non_string
      assert_nil(scrub(nil))
    end

    # ⚠ **クラスメソッドからも使う。**`Webhook.create` の rescue は key（＝digest）を
    # ログへ出す。
    def test_webhook_class_scrubs_digest
      assert_equal('a1b2c3d4a1b2...', Webhook.scrub_log_digest(DIGEST))
    end

    # ⚠⚠ **回帰の本体はここ。**`Controller` がログへ渡すパスは必ず
    # `scrub_log_path` を通す。素の `request.path` を書き戻したら落ちる。
    #
    # ⚠ **素の `request.path` が許されるのは 1 箇所だけ** — `not_found` が
    # **要求した本人へ返すボディ**（ログではない。丸めても秘匿にならず、
    # 404 のボディという api.md の契約が変わるだけ）。
    def test_controller_never_logs_raw_path
      source = File.read(File.join(Environment.dir, 'app/lib/mulukhiya/controller.rb'))
      # ⚠ コメント行は数えない（この注記自体が `request.path` を含む）。
      code = source.lines.reject {|line| line.strip.start_with?('#')}.join
      bare = code.scan(/(?<!scrub_log_path\()request\.path/)

      assert_not_match(/path: request\.path/, code)
      assert_equal(1, bare.size, "素の request.path が #{bare.size} 箇所ある")
      assert_match(/Resource .\{request\.path\} not found/, code)
    end
  end
end
