module Mulukhiya
  class StartupNotificationWorkerTest < TestCase
    def disable?
      return true unless info_agent_service
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:startup_notification)
    end

    def test_create_startup_message
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'OK'},
        postgres: {status: 'OK'},
        status: 200,
      }
      message = @worker.send(:create_startup_message, health)

      assert_kind_of(String, message)
      assert_match(/モロヘイヤ v/, message)
      assert_match(/ステータス: 正常/, message)
      assert_match(/redis: OK/, message)
    end

    def test_create_startup_message_ng
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'NG', error: 'listener process not found'},
        postgres: {status: 'OK'},
        status: 503,
      }
      message = @worker.send(:create_startup_message, health)

      assert_match(/ステータス: 異常/, message)
      assert_match(/streaming: NG/, message)
    end

    def test_create_startup_message_warn
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'OK'},
        postgres: {status: 'WARN', reason: 'pool_exhausted'},
        status: 200,
      }
      message = @worker.send(:create_startup_message, health)

      assert_match(/ステータス: 正常/, message)
      assert_match(/postgres: WARN/, message)
    end

    def test_create_startup_message_schema_ok
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'OK'},
        postgres: {status: 'OK'},
        status: 200,
      }
      message = @worker.send(:create_startup_message, health)

      refute_match(/スキーマエラー/, message)
    end

    def test_create_change_message
      new_reported = {redis: 'OK', sidekiq: 'OK', streaming: 'OK', postgres: 'OK'}
      reported = {redis: 'OK', sidekiq: 'OK', streaming: 'NG', postgres: 'OK'}
      message = @worker.send(:create_change_message, new_reported, reported)

      assert_match(/ヘルスステータス変更/, message)
      assert_match(/streaming: NG → OK/, message)
      assert_match(/ステータス: 正常/, message)
    end

    def test_create_change_message_degraded
      new_reported = {redis: 'OK', sidekiq: 'OK', streaming: 'NG', postgres: 'OK'}
      reported = {redis: 'OK', sidekiq: 'OK', streaming: 'OK', postgres: 'OK'}
      message = @worker.send(:create_change_message, new_reported, reported)

      assert_match(/ヘルスステータス変更/, message)
      assert_match(/streaming: OK → NG/, message)
      assert_match(/ステータス: 異常/, message)
    end

    def test_create_change_message_warn
      new_reported = {redis: 'OK', sidekiq: 'OK', streaming: 'OK', postgres: 'WARN'}
      reported = {redis: 'OK', sidekiq: 'OK', streaming: 'OK', postgres: 'OK'}
      message = @worker.send(:create_change_message, new_reported, reported)

      assert_match(/postgres: OK → WARN/, message)
      assert_match(/ステータス: 正常/, message)
    end

    def test_extract_status
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'NG', error: 'listener process not found'},
        status: 503,
      }
      result = @worker.send(:extract_status, health)

      assert_equal({redis: 'OK', sidekiq: 'OK', streaming: 'NG'}, result)
    end

    def test_apply_hysteresis_ng_below_threshold
      return if disable?
      observed = {redis: 'OK', postgres: 'NG'}
      reported = {redis: 'OK', postgres: 'OK'}
      @worker.send(:reset_ng_count, :postgres)
      result = @worker.send(:apply_hysteresis, observed, reported)

      assert_equal('OK', result[:postgres])
    ensure
      @worker&.send(:reset_ng_count, :postgres)
    end

    def test_apply_hysteresis_ng_at_threshold
      return if disable?
      observed = {redis: 'OK', postgres: 'NG'}
      reported = {redis: 'OK', postgres: 'OK'}
      @worker.send(:reset_ng_count, :postgres)
      @worker.send(:apply_hysteresis, observed, reported)
      result = @worker.send(:apply_hysteresis, observed, reported)

      assert_equal('NG', result[:postgres])
    ensure
      @worker&.send(:reset_ng_count, :postgres)
    end

    def test_apply_hysteresis_warn_passes_through
      return if disable?
      observed = {redis: 'OK', postgres: 'WARN'}
      reported = {redis: 'OK', postgres: 'OK'}
      result = @worker.send(:apply_hysteresis, observed, reported)

      assert_equal('WARN', result[:postgres])
    end

    def test_apply_hysteresis_ok_resets_counter
      return if disable?
      observed_ng = {postgres: 'NG'}
      reported = {postgres: 'OK'}
      @worker.send(:reset_ng_count, :postgres)
      @worker.send(:apply_hysteresis, observed_ng, reported)

      observed_ok = {postgres: 'OK'}
      @worker.send(:apply_hysteresis, observed_ok, reported)

      result = @worker.send(:apply_hysteresis, observed_ng, reported)

      assert_equal('OK', result[:postgres])
    ensure
      @worker&.send(:reset_ng_count, :postgres)
    end
  end
end
