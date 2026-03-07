module Mulukhiya
  class ListenerTest < TestCase
    def disable?
      return true unless controller_class.streaming?
      return super
    end

    def setup
      return if disable?
      @listener_class = Environment.listener_class
      @listener = @listener_class.new if Environment.daemon_classes.member?(ListenerDaemon)
    end

    def teardown
      @listener_class&.instance_variable_set(:@retry_count, 0)
      Redis.new.del('listener:last_event')
    rescue
      nil
    end

    def test_verify_peer?
      return false unless @listener
      expected = config["/#{Environment.controller_name}/streaming/verify_peer"]

      assert_boolean(@listener.verify_peer?)
      assert_equal(expected, @listener.verify_peer?)
    end

    def test_root_cert_file
      return unless @listener

      assert_path_exist(@listener.root_cert_file)
    end

    def test_keepalive
      return unless @listener

      assert_predicate(@listener.keepalive, :positive?)
    end

    def test_underscore
      return unless @listener

      assert_kind_of(String, @listener.underscore)
    end

    def test_retry_delay
      @listener_class.instance_variable_set(:@retry_count, 1)

      assert_equal(config['/websocket/retry/seconds'], @listener_class.retry_delay)
    end

    def test_retry_delay_backoff
      @listener_class.instance_variable_set(:@retry_count, 3)
      expected = config['/websocket/retry/seconds'] * 4

      assert_equal(expected, @listener_class.retry_delay)
    end

    def test_retry_delay_cap
      @listener_class.instance_variable_set(:@retry_count, 100)

      assert_equal(config['/websocket/retry/max_seconds'], @listener_class.retry_delay)
    end

    def test_touch_last_event
      return unless Redis.health[:status] == 'OK'
      @listener_class.touch_last_event
      timestamp = Redis.new.get('listener:last_event')&.to_i

      assert_not_nil(timestamp)
      assert_in_delta(Time.now.to_i, timestamp, 2)
    end
  end
end
