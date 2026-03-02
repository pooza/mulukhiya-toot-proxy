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

    def test_create_message
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'OK'},
        postgres: {status: 'OK'},
        status: 200,
      }
      message = @worker.send(:create_message, health)

      assert_kind_of(String, message)
      assert_match(/モロヘイヤ v/, message)
      assert_match(/ステータス: 正常/, message)
      assert_match(/redis: OK/, message)
    end

    def test_create_message_ng
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'NG', error: 'listener process not found'},
        postgres: {status: 'OK'},
        status: 503,
      }
      message = @worker.send(:create_message, health)

      assert_match(/ステータス: 異常/, message)
      assert_match(/streaming: NG/, message)
    end

    def test_create_message_schema_ok
      health = {
        redis: {status: 'OK'},
        sidekiq: {status: 'OK', queues: 0, retry: 0},
        streaming: {status: 'OK'},
        postgres: {status: 'OK'},
        status: 200,
      }
      message = @worker.send(:create_message, health)

      refute_match(/スキーマエラー/, message)
    end
  end
end
