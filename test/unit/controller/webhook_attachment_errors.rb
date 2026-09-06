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

    def build_reporter(errors, parsed_response = UPSTREAM.dup)
      reporter = Reporter.new
      reporter.errors.concat(errors)
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
