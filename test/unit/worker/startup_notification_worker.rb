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
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'OK'},
        postgres: {status: 'OK'},
        status: 200,
      }
      previous = {redis: 'OK', sidekiq: 'OK', streaming: 'NG', postgres: 'OK'}
      message = @worker.send(:create_change_message, health, previous)

      assert_match(/ヘルスステータス変更/, message)
      assert_match(/streaming: NG → OK/, message)
      assert_match(/ステータス: 正常/, message)
    end

    def test_create_change_message_degraded
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'NG', error: 'listener process not found'},
        postgres: {status: 'OK'},
        status: 503,
      }
      previous = {redis: 'OK', sidekiq: 'OK', streaming: 'OK', postgres: 'OK'}
      message = @worker.send(:create_change_message, health, previous)

      assert_match(/ヘルスステータス変更/, message)
      assert_match(/streaming: OK → NG/, message)
      assert_match(/ステータス: 異常/, message)
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
  end
end
