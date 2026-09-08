module Mulukhiya
  # `Reporter` が errors を result と分けて保持すること (#4649)。
  #
  # ⚠⚠ **`Handler#summary` は result と errors を 1 本に混ぜる。**混ざった後では
  # 「どれが落ちたか」を取り出せないので、`Reporter#push` が混ぜる前に控える。
  class ReporterErrorsTest < TestCase
    # ⚠ `Handler.new` は SNS 経由で DB を触るので `allocate` で組む。
    # `Reporter#push` が触るのは `is_a?(Handler)` と `errors` /
    # `reportable?` / `loggable?` / `summary` だけ。
    class HandlerDouble < Handler
      attr_writer :reportable, :loggable

      def self.build(result: [], errors: [], reportable: false, loggable: false)
        handler = allocate
        handler.instance_variable_set(:@event, :pre_webhook)
        handler.instance_variable_set(:@result, Concurrent::Array.new(result))
        handler.instance_variable_set(:@errors, Concurrent::Array.new(errors))
        handler.reportable = reportable
        handler.loggable = loggable
        return handler
      end

      def reportable? = @reportable

      def loggable? = @loggable
    end

    def setup
      @reporter = Reporter.new
    end

    def test_errors_is_empty_by_default
      assert_empty(@reporter.errors)
    end

    # ⚠⚠ **これが本命。**`reportable?` も `loggable?` も false でも拾うこと。
    # あれらは「運用者へ通知する / ログへ出す」の判定で、**送信側への応答とは別の話**。
    # `notify_verbose?` が false のアカウントでも落ちた添付は返す。
    def test_errors_are_collected_even_when_not_reportable
      @reporter.push(HandlerDouble.build(errors: [{message: 'dropped'}]))

      assert_equal([{message: 'dropped'}], @reporter.errors)
    end

    # result は errors に混ざらない。
    def test_result_is_not_collected_as_error
      @reporter.push(HandlerDouble.build(result: [{source_url: 'https://example.com/a.png'}]))

      assert_empty(@reporter.errors)
    end

    def test_errors_accumulate_across_handlers
      @reporter.push(HandlerDouble.build(errors: [{message: 'first'}]))
      @reporter.push(HandlerDouble.build(errors: [{message: 'second'}]))

      assert_equal([{message: 'first'}, {message: 'second'}], @reporter.errors)
    end

    # ⚠ ハンドラ側の `errors` を後から触っても Reporter の控えは動かない
    # （`concat` で写しているので参照を共有しない）。
    def test_collected_errors_are_detached
      handler = HandlerDouble.build(errors: [{message: 'first'}])
      @reporter.push(handler)
      handler.errors.push({message: 'later'})

      assert_equal([{message: 'first'}], @reporter.errors)
    end
  end
end
