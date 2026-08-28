module Mulukhiya
  # クライアント起因の失敗を Sentry alert に上げない (#4542 / #4594 / #4603 / #4629)。
  #
  # ⚠⚠ **同じ方針が 3 系統で別々に書かれ、そのたびに取りこぼした。**
  # #4603 は `NotFoundError`、#4629 は `AuthError` と `NotFoundError` が `else` へ
  # 落ちて alert していた。**「実際に alert しないこと」を正面から確かめる。**
  class ClientErrorAlertTest < TestCase
    # status を持つ例外のダブル。report_error が見るのは status だけ。
    class ErrorDouble
      attr_reader :calls, :status

      def initialize(status)
        @status = status
        @calls = []
      end

      def alert = @calls << :alert
      def log = @calls << :log
    end

    # ⚠ status を持たない素の例外（NoMethodError 等）はモロヘイヤ自身のバグ。
    class StatuslessDouble
      attr_reader :calls

      def initialize = @calls = []
      def alert = @calls << :alert
      def log = @calls << :log
    end

    def setup
      @controller = MisskeyController.new!
    end

    def test_client_errors_are_logged_not_alerted
      [400, 401, 403, 404, 409, 422, 499].each do |status|
        error = ErrorDouble.new(status)
        @controller.report_error(error)

        assert_equal([:log], error.calls, "status #{status} は log であるべき")
      end
    end

    def test_server_errors_are_alerted
      [500, 502, 503].each do |status|
        error = ErrorDouble.new(status)
        @controller.report_error(error)

        assert_equal([:alert], error.calls, "status #{status} は alert であるべき")
      end
    end

    # ⚠ 黙らせてよいのはステータスで「クライアント起因」と言えるものだけ。
    def test_statusless_error_is_alerted
      error = StatuslessDouble.new
      @controller.report_error(error)

      assert_equal([:alert], error.calls)
    end

    def test_client_error_predicate
      assert_true(@controller.client_error?(ErrorDouble.new(404)))
      assert_false(@controller.client_error?(ErrorDouble.new(500)))
      assert_false(@controller.client_error?(StatuslessDouble.new))
    end
  end

  # 引き当ての失敗を「未知の digest」の 404 に化かさない (#4603 の Codex P1)。
  #
  # ⚠⚠ **かつて `Webhook.create` が全例外を握って nil を返していた。**それを
  # `verify_webhook!` が 404 に変換するので、alert 抑止を入れると
  # **DB 障害で全 webhook が落ちている状態が無音になる**。#4657 で `create` 自体を
  # 削除したが、`create!` の例外が alert 側へ倒れることは引き続き押さえる。
  class WebhookLookupFailureTest < TestCase
    class LookupError < StandardError; end

    # ⚠ **引き当ての失敗はそのまま上がる。**呼び側は「そんな digest は無い」と
    # 区別できる。⚠ 全例外を握って nil を返す `create` は #4657 で削除した。
    def test_create_bang_propagates
      with_failing_lookup do
        assert_raise(LookupError) {Webhook.create!('deadbeef')}
      end
    end

    # ⚠ 上がってきた例外は `status` を持たないので、`report_error` は alert 側へ倒す。
    def test_lookup_failure_is_alerted
      error = LookupError.new('connection refused')
      calls = []
      error.define_singleton_method(:alert) {calls << :alert}
      error.define_singleton_method(:log) {calls << :log}

      MisskeyController.new!.report_error(error)

      assert_equal([:alert], calls)
    end

    private

    def with_failing_lookup
      Webhook.singleton_class.alias_method(:__orig_find_token_by_digest, :find_token_by_digest)
      Webhook.define_singleton_method(:find_token_by_digest) {|_| raise LookupError, 'connection refused'}
      yield
    ensure
      Webhook.singleton_class.alias_method(:find_token_by_digest, :__orig_find_token_by_digest)
      Webhook.singleton_class.remove_method(:__orig_find_token_by_digest)
    end
  end

  # 番組表編集 5 本の rescue (#4629)。
  class ProgramEntryErrorHandlingTest < TestCase
    def setup
      @controller = APIController.new!
    end

    # ⚠⚠ **これが #4629 そのもの。**無効トークン・非管理者トークンで叩かれるたびに
    # Sentry イベントと管理者へのアラートメールが飛んでいた。
    def test_auth_error_is_not_alerted
      error = spy(Ginseng::AuthError.new('Unauthorized'))
      handle(error)

      assert_equal([:log], error.mulukhiya_calls)
    end

    # 非 livecure サーバーへ誤って叩かれると 404 で毎回鳴っていた。
    def test_not_found_error_is_not_alerted
      error = spy(Ginseng::NotFoundError.new('Not Found'))
      handle(error)

      assert_equal([:log], error.mulukhiya_calls)
    end

    # 409 / 422 は期待動作なので、log でも alert でもなく構造化ログだけ残す。
    def test_conflict_and_validate_are_structured_only
      [Ginseng::ConflictError.new('conflict'), Ginseng::ValidateError.new('invalid')].each do |raw|
        error = spy(raw)
        handle(error)

        assert_equal([], error.mulukhiya_calls, "#{raw.class} は log/alert しない")
      end
    end

    # モロヘイヤ自身のバグは黙らせない。
    def test_server_error_is_alerted
      error = spy(Ginseng::GatewayError.new('Bad response 502'))
      handle(error)

      assert_equal([:alert], error.mulukhiya_calls)
    end

    private

    def handle(error)
      @controller.send(:handle_program_entry_error, error, 'precure')
    end

    def spy(error)
      calls = []
      error.define_singleton_method(:mulukhiya_calls) {calls}
      error.define_singleton_method(:alert) {calls << :alert}
      error.define_singleton_method(:log) {calls << :log}
      return error
    end
  end
end
