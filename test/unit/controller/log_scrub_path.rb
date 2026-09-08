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
    # ⚠ 3 バイト文字の途中で切れたバイト列（`logger_mask_boundary.rb` と同じ形）。
    BROKEN = "\xFF".dup.force_encoding(Encoding::UTF_8).freeze

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

    # ⚠⚠ **パーセントエンコードを解いてからも見る（PR #4664 の Codex P1）。**
    # `request.path` は生のままで、Sinatra の `params[:digest]` だけがデコード済み。
    # `%61` を 1 文字混ぜるだけで **引き当ては成功するのにログには丸ごと残る**
    # という抜け道が開いていた（実測で確認済み）。
    def test_scrubs_percent_encoded_digest
      encoded = "%61#{DIGEST[1..]}"
      scrubbed = scrub("/mulukhiya/webhook/#{encoded}")

      assert_not_match(/#{DIGEST[1, 32]}/o, scrubbed)
      assert_equal('/mulukhiya/webhook/a1b2c3d4a1b2...', scrubbed)
    end

    # ⚠ **エンコードの有無で見え方が変わらないこと。**残す 12 文字はデコード後のもので、
    # `verify_webhook!` のエラーメッセージ（`params[:digest]` 由来）と揃う。
    def test_encoded_and_raw_digests_render_identically
      assert_equal(
        scrub("/mulukhiya/webhook/#{DIGEST}"),
        scrub("/mulukhiya/webhook/%61#{DIGEST[1..]}"),
      )
    end

    # ⚠ **普通のエスケープを壊さない。**デコード後が digest でなければ生のまま返す。
    def test_keeps_ordinary_escaped_segments
      assert_equal('/x/%E3%81%82', scrub('/x/%E3%81%82'))
    end

    # ⚠ **解けない値でも落とさない。**ログ行そのものが消えるほうが困る。
    def test_tolerates_broken_escape
      assert_equal('/x/%zz', scrub('/x/%zz'))
    end

    # ⚠⚠ **不正なバイト列で例外を上げない（PR #4666 の Codex P2）。**
    # `String#match?` も `String#split` も不正な UTF-8 で `ArgumentError` を上げる。
    # ⚠ ここは `Controller#before` のログ行を組む途中なので、上げると
    # **request ログが丸ごと消え、`before` の rescue に落ちて `@sns` 未設定のまま
    # 経路が進む**（malformed な URL 1 本で 500 にできた）。
    # ⚠ **[[project_log-credential-exposure]] と同型**（gem 側でも `mask_urls_in` が
    # 同じ理由でマスクごと外れていた。pooza/ginseng-core#587）。
    def test_tolerates_invalid_byte_sequence
      # `%FF` は `unescape_path` が **例外なしで不正な UTF-8 を返す**（rescue では捕まらない）。
      assert_equal('/x/%FF', scrub('/x/%FF'))
      assert_equal("/x/#{BROKEN}", scrub("/x/#{BROKEN}"))
    end

    # ⚠ **壊れたバイトが混ざっても、digest の秘匿は効き続けること。**
    # 素通しに倒すと「1 バイト混ぜればマスクを外せる」に戻る。
    def test_scrubs_digest_next_to_invalid_byte_sequence
      # ⚠ 検査する側も不正なバイト列で `ArgumentError` を上げるので、
      #   **アサーションの直前だけ** `String#scrub` を通す（本体の戻り値は生のまま）。
      scrubbed = scrub("/mulukhiya/webhook/#{BROKEN}/#{DIGEST}").scrub

      assert_not_match(DIGEST_PATTERN, scrubbed)
      assert_match(/a1b2c3d4a1b2\.\.\./, scrubbed)
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

    # ⚠ **クラスメソッドからも引ける**ことを押さえる。digest をログへ出す経路が
    # クラス側に生えたときに、素の値が漏れないため。
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
