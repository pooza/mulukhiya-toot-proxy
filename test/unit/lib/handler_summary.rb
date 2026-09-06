module Mulukhiya
  # `Handler#summary` が `result` を壊さないこと (#4682)。
  #
  # ⚠⚠ **従来は `result.concat(errors)` と破壊的だった。**`Reporter#push` は
  # 1 つのハンドラに対して `summary` を 2 回呼ぶ（`push` 側と `logger.info` 側）ので、
  # **ログの方だけ `errors` が 2 回入る**。通知と突き合わせると件数が合わない。
  class HandlerSummaryTest < TestCase
    # ⚠ `Handler.new` は SNS 経由で DB を触るので `allocate` で組む。
    # `summary` が読むのは `@event` / `@result` / `@errors` だけ。
    def create_handler(result:, errors:)
      handler = Handler.allocate
      handler.instance_variable_set(:@event, :pre_toot)
      handler.instance_variable_set(:@result, Concurrent::Array.new(result))
      handler.instance_variable_set(:@errors, Concurrent::Array.new(errors))
      return handler
    end

    def test_entries_merges_result_and_errors
      handler = create_handler(result: ['R1'], errors: ['E1'])

      assert_equal(['R1', 'E1'], handler.summary[:entries])
    end

    # ⚠⚠ **これが本命。**従来は 2 回目が `['R1', 'E1', 'E1']` になっていた。
    def test_summary_is_idempotent
      handler = create_handler(result: ['R1'], errors: ['E1'])

      assert_equal(handler.summary[:entries], handler.summary[:entries])
      assert_equal(['R1', 'E1'], handler.summary[:entries])
    end

    # `errors` が `result` に染み出さないこと。染み出すと `debug_info[:result]` が
    # 「成功した結果」でなくなり、`loggable?` の判定も変わる。
    def test_summary_does_not_pollute_result
      handler = create_handler(result: ['R1'], errors: ['E1'])
      3.times {handler.summary}

      assert_equal(['R1'], handler.result)
      assert_equal(['E1'], handler.errors)
      assert_equal({result: ['R1'], errors: ['E1']}, handler.debug_info)
    end

    def test_summary_without_errors
      handler = create_handler(result: ['R1'], errors: [])
      2.times {handler.summary}

      assert_equal(['R1'], handler.summary[:entries])
      assert_equal(['R1'], handler.result)
    end

    def test_summary_without_result
      handler = create_handler(result: [], errors: ['E1'])
      2.times {handler.summary}

      assert_equal(['E1'], handler.summary[:entries])
      assert_empty(handler.result)
    end
  end
end
