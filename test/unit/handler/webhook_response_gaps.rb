module Mulukhiya
  # webhook 応答の穴 4 件 (#4694)。
  #
  # ⚠⚠ **#4657 の `thread.kill` は `handle_pre_webhook` を途中で切る。**素直に
  # `run_workers` の後ろへ `drain` を書くと、**タイムアウト経路でだけ実行されない**。
  # `drain` は「枠切れ・未処理で残った添付」を `record_drop` する**唯一の経路**なので、
  # 🔴 走らないとキューに残った添付が syslog にも応答にも 1 行も残らない。
  class WebhookResponseGapsTest < TestCase
    # ⚠ `WebhookImageHandler.new` は `Ginseng::Fediverse::Service` を作るので
    # **DB 接続が要る**（`Environment.account_class` が Sequel モデル）。
    # ここで見たいのは `drain` の走行と文言の丸めだけなので `allocate` で作り、
    # 必要な内部状態だけ与える。
    def setup
      @handler = WebhookImageHandler.allocate
      # ⚠ `TestCase#teardown` が `@handler.clear` を呼ぶので、そこが触る
      # ivar は揃えておく（allocate では initialize が走らない）。
      @handler.instance_variable_set(:@errors, Concurrent::Array.new)
      @handler.instance_variable_set(:@result, Concurrent::Array.new)
      @handler.instance_variable_set(:@reporter, Reporter.new)
      @handler.instance_variable_set(:@break, false)
      @handler.define_singleton_method(:attachment_field) {'media_ids'}
      @handler.define_singleton_method(:create_slots) {|*| Concurrent::AtomicFixnum.new(0)}
    end

    # 🔴 **① スレッドを殺されても `drain` が走る。**
    # ⚠ `Thread#kill` は殺されるスレッドの `ensure` を走らせるので、
    # `handle_pre_webhook` 自身の `ensure` に置けば必ず通る。
    def test_drain_runs_even_when_the_thread_is_killed
      # `run_workers` が返らないまま殺される状況を作る。⚠ 実際のタイムアウトは
      # `Event#run_handler` の `thread.kill` なので、形は同じ。
      @handler.define_singleton_method(:run_workers) {|*| sleep(10)}
      payload = {'attachments' => [
        {'image_url' => 'https://example.com/a.png'},
        {'image_url' => 'https://example.com/b.png'},
      ]}

      thread = Thread.new {@handler.handle_pre_webhook(payload)}
      sleep(0.1)
      thread.kill
      thread.join(3)

      assert_equal(2, @handler.errors.length, '殺された後に drain が走っていない')
      assert(@handler.errors.all? {|e| e[:class] == 'SlotExhausted'})
    end

    # 🔴 **①-b 取り出し済みで処理中だった添付も残る（PR #4713 の Codex P1）。**
    #
    # ⚠⚠ `pop_attachment` はキューから**取り除いてから**アップロードに入るので、
    # その最中に殺されると **キューにも残らず `rescue` も通らない**
    # （`Thread#kill` は `rescue => e` を通さない）。⚠ **添付 1 枚 = ワーカー 1 本**
    # という最も普通の形でキューが空になり、`drain` だけでは何も残らなかった。
    def test_inflight_attachments_are_recorded_when_killed
      # アップロードで固まるワーカーを作る。⚠ `parse_image_uri` は通す。
      # ⚠ setup の `create_slots` は 0 枠なので、ここだけ枠を開ける
      # （0 枠だとキューから取り出されず `SlotExhausted` の側になる）。
      @handler.define_singleton_method(:create_slots) {|*| Concurrent::AtomicFixnum.new(4)}
      @handler.define_singleton_method(:upload_attachment) {|*| sleep(10)}
      payload = {'attachments' => [{'image_url' => 'https://example.com/a.png'}]}

      thread = Thread.new {@handler.handle_pre_webhook(payload)}
      sleep(0.3)
      thread.kill
      thread.join(5)

      assert_equal(1, @handler.errors.length, '処理中だった添付が残っていない')
      assert_equal('Timeout', @handler.errors.first[:class])
    end

    # 🔴 **①-c 同じ内容の添付が 2 枚あっても取りこぼさない（PR #4713 の Codex P1）。**
    #
    # ⚠⚠ `Concurrent::Array#delete` は**値の等価**で消すので、**先に終わった
    # ワーカーがまだ走っている別ワーカーの分まで消して**しまう。そのワーカーが
    # 締切で殺されると、キューにも控えにも残らず**また無音で落ちる**。
    def test_duplicate_attachments_are_tracked_independently
      attachment = {'image_url' => 'https://example.com/same.png'}
      # ⚠ **両方が控えに載ってから、片方だけが先に終わる**形を作る。
      # 素直に「1 枚目は即終わり」にすると、**2 枚目が控えに載る前に 1 枚目が
      # 終わってしまい競合が起きない**（実際に false negative を踏んだ）。
      calls = Concurrent::AtomicFixnum.new(0)
      @handler.define_singleton_method(:create_slots) {|*| Concurrent::AtomicFixnum.new(4)}
      @handler.define_singleton_method(:upload_attachment) do |*|
        sleep(calls.increment == 1 ? 0.3 : 10)
      end
      payload = {'attachments' => [attachment.dup, attachment.dup]}

      thread = Thread.new {@handler.handle_pre_webhook(payload)}
      sleep(1.0)
      thread.kill
      thread.join(5)

      assert_equal(1, @handler.errors.length, '重複した添付が取りこぼされている')
      assert_equal('Timeout', @handler.errors.first[:class])
    end

    # 🔴 **② 内部例外の生メッセージを送信側へ返さない。**
    # ⚠⚠ 素通しすると **サーバー内の絶対パス**や**内部ホスト・ポート**が第三者へ返る。
    def test_internal_exception_message_is_not_leaked
      error = Errno::EACCES.new('/home/mulukhiya/repos/x/tmp/media/secret.jpg')

      assert_equal(
        WebhookImageHandler::GENERIC_DROP_MESSAGE,
        @handler.send(:client_message, error),
      )
    end

    # ⚠ `Ginseng::Error` 系は送信側が対処できる情報なので通す
    # （上限超過・取得失敗の理由）。
    def test_ginseng_error_message_is_passed_through
      error = Ginseng::TooLargeError.new('too large')

      assert_equal('too large', @handler.send(:client_message, error))
    end

    # ⚠⚠ **原文は syslog に残す。**外に出さないことと、こちらが見られなくなる
    # ことは別。
    def test_original_message_still_reaches_syslog
      logged = []
      double = Object.new
      double.define_singleton_method(:error) {|payload| logged.push(payload)}
      double.define_singleton_method(:info) {|*| nil}
      @handler.define_singleton_method(:logger) {double}

      @handler.send(:drop_attachment, Errno::EACCES.new('/home/secret/path.jpg'), {})

      assert_match(%r{/home/secret/path\.jpg}, logged.first[:message].to_s)
      assert_equal(WebhookImageHandler::GENERIC_DROP_MESSAGE, @handler.errors.first[:message])
    end

    # 🔴 **③ `url` が nil にならない。**`docs/api.md` は string と書いている。
    def test_url_key_is_omitted_when_absent
      entries = attachment_errors([
        {attachment: {'image_url' => 'https://example.com/a.png'}, message: 'x'},
        {attachment: {'text' => 'no image_url here'}, message: 'y'},
      ])

      assert_equal('https://example.com/a.png', entries[0]['url'])
      refute(entries[1].key?('url'), 'url が null で載っている')
      assert_equal('y', entries[1]['message'])
    end

    private

    def attachment_errors(errors)
      reporter = Reporter.new
      errors.each {|e| reporter.errors.push(e)}
      controller = WebhookController.allocate
      return controller.send(:attachment_errors, reporter)
    end
  end
end
