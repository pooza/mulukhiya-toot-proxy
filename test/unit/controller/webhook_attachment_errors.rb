module Mulukhiya
  # 落ちた添付を送信側へ返す (#4649)。
  #
  # ⚠⚠ **従来は上流の status entity をそのまま返していた。**`WebhookImageHandler` は
  # per-attachment の `rescue` で失敗を握るので、**200 と作成済み投稿 ID が返るのに
  # 画像が付いていない**。運用者は syslog で気づけるが、送信側は気づけなかった。
  class WebhookAttachmentErrorsTest < TestCase
    # 上流レスポンスのダブル。`webhook_response_body` が見るのは
    # `parsed_response` だけ（`code` は呼び出し元が使う）。
    ResponseDouble = Struct.new(:code, :parsed_response)

    UPSTREAM = {'id' => '114514', 'content' => '<p>ほげ</p>', 'media_attachments' => []}.freeze

    def setup
      @controller = WebhookController.new!
    end

    def build_reporter(errors, parsed_response = UPSTREAM.dup, sent: nil)
      reporter = Reporter.new
      reporter.errors.concat(errors)
      reporter.temp[:attachment_count] = sent unless sent.nil?
      reporter.response = ResponseDouble.new(200, parsed_response)
      return reporter
    end

    def body(reporter)
      return @controller.send(:webhook_response_body, reporter)
    end

    # ⚠ **落ちた添付が無ければキーを足さない。**常時付けると entity の形が常に変わる。
    def test_body_is_untouched_without_errors
      assert_equal(UPSTREAM, body(build_reporter([])))
    end

    def test_dropped_attachment_is_returned
      reporter = build_reporter([{
        class: 'TooLargeError',
        message: 'file too large (41.2MiB > 32MiB)',
        attachment: {'image_url' => 'https://example.com/big.png'},
      }])

      assert_equal(
        [{'url' => 'https://example.com/big.png', 'message' => 'file too large (41.2MiB > 32MiB)'}],
        body(reporter).dig('mulukhiya', 'attachment_errors'),
      )
    end

    # 上流の entity は 1 バイトも変えない。未知のキーを無視する既存クライアントが
    # 壊れないことの裏。
    def test_upstream_entity_is_preserved
      reporter = build_reporter([{
        class: 'SlotExhausted',
        message: 'max media attachments exceeded',
        attachment: {'image_url' => 'https://example.com/5th.png'},
      }])

      assert_equal(UPSTREAM, body(reporter).except('mulukhiya'))
    end

    # 文字列キーの entry でも拾えること（`recursive_to_a` を経た形）。
    def test_string_keyed_error_entry
      reporter = build_reporter([{
        'class' => 'SlotExhausted',
        'message' => 'max media attachments exceeded',
        'attachment' => {'image_url' => 'https://example.com/5th.png'},
      }])

      assert_equal(
        [{'url' => 'https://example.com/5th.png', 'message' => 'max media attachments exceeded'}],
        body(reporter).dig('mulukhiya', 'attachment_errors'),
      )
    end

    # ⚠ **添付に紐づかない失敗は返さない。**ハンドラのタイムアウト等は送信側が
    # 対処できる情報ではない。
    def test_non_attachment_error_is_ignored
      reporter = build_reporter([{message: 'timeout'}])

      assert_nil(body(reporter)['mulukhiya'])
    end

    # ⚠⚠ **添付を丸ごと返さない (#4630 の穴をレスポンス側で開け直さない)。**
    # 本文系は `scrub_log_params` で `[FILTERED]` になっているが、それでも
    # `url` と `message` だけに絞る。
    def test_only_url_and_message_are_returned
      reporter = build_reporter([{
        class: 'TooLargeError',
        message: 'file too large',
        attachment: {
          'image_url' => 'https://example.com/big.png',
          'title' => '[FILTERED]',
          'text' => '[FILTERED]',
          'fallback' => 'まだ伏せていない何か',
        },
      }])

      entry = body(reporter).dig('mulukhiya', 'attachment_errors').first

      assert_equal(['url', 'message'], entry.keys)
    end

    # ⚠⚠ **`Idempotency-Key` の再送（PR #4684 の Codex P1）。**上流は初回の
    # キャッシュ済み投稿を返すので、**このリクエストのアップロードが成功していても
    # 応答には載らない**。errors が空だからと `mulukhiya` を落とすと「全部通った」と
    # 嘘をつくことになる。
    def test_missing_attachment_is_reported_without_errors
      reporter = build_reporter([], {'id' => '114514', 'media_attachments' => []}, sent: 1)

      assert_equal(1, body(reporter).dig('mulukhiya', 'missing_attachments'))
    end

    def test_no_missing_when_upstream_returned_everything
      reporter = build_reporter([], {'id' => '114514', 'media_attachments' => [{'id' => '1'}]}, sent: 1)

      assert_nil(body(reporter)['mulukhiya'])
    end

    # ⚠⚠ **Misskey は `createdNote.files`。**トップレベルの `files` を読むと
    # 常に見つからず、毎回「全部欠けている」と誤判定する。
    def test_misskey_response_shape
      reporter = build_reporter([], {'createdNote' => {'id' => 'x', 'files' => [{'id' => '1'}]}}, sent: 1)

      assert_nil(body(reporter)['mulukhiya'])
    end

    def test_misskey_missing_attachment
      reporter = build_reporter([], {'createdNote' => {'id' => 'x', 'files' => []}}, sent: 2)

      assert_equal(2, body(reporter).dig('mulukhiya', 'missing_attachments'))
    end

    # ⚠ **分からないときは黙る。**応答の形が未知なら「欠けている」と言わない。
    def test_unknown_response_shape_claims_nothing
      reporter = build_reporter([], {'id' => '114514'}, sent: 3)

      assert_nil(body(reporter)['mulukhiya'])
    end

    # 渡した本数を控えていない経路でも「欠けている」と言わない。
    def test_without_sent_count_claims_nothing
      reporter = build_reporter([], {'id' => '114514', 'media_attachments' => []})

      assert_nil(body(reporter)['mulukhiya'])
    end

    # 落ちた添付は errors、載らなかった分は missing_attachments。二重計上しない。
    def test_errors_and_missing_coexist
      reporter = build_reporter(
        [{message: 'file too large', attachment: {'image_url' => 'https://example.com/big.png'}}],
        {'id' => '114514', 'media_attachments' => []},
        sent: 1,
      )
      entity = body(reporter)['mulukhiya']

      assert_equal(1, entity['attachment_errors'].size)
      assert_equal(1, entity['missing_attachments'])
    end

    # ⚠ 上流が渡した本数より**多く**返すことは無いが、負の値を返さないこと。
    def test_never_reports_negative
      reporter = build_reporter([], {'id' => '114514', 'media_attachments' => [{'id' => '1'}, {'id' => '2'}]}, sent: 1)

      assert_nil(body(reporter)['mulukhiya'])
    end

    # ⚠ 上流が Hash 以外（配列・エラーページの文字列）を返すことがある。
    # その形に追加キーは足せないので素通しする。
    def test_non_hash_body_passes_through
      reporter = build_reporter(
        [{message: 'x', attachment: {'image_url' => 'https://example.com/a.png'}}],
        '<html><body>Bad Gateway</body></html>',
      )

      assert_equal('<html><body>Bad Gateway</body></html>', body(reporter))
    end
  end
end
