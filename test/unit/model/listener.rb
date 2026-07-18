module Mulukhiya
  class ListenerTest < TestCase
    def disable?
      return true unless controller_class.streaming?
      return super
    end

    def setup
      return if disable?
      @listener_class = Environment.listener_class
      return unless Environment.daemon_classes.member?(ListenerDaemon)

      # Listener 構築は Mastodon instance info の urls.streaming_api を要する。harness は
      # streaming を提供せず nil のため構築できない（create_streaming_uri が nil.path= で落ちる）。
      # ここでは omit せず @listener を nil のままにする。omit を setup に置くと @listener を
      # 使わない class-only テスト（retry_delay 系）まで巻き込むため、@listener を実際に使う
      # テストだけが require_listener! でゲートする（#4447）。streaming provisioning は chubo2#63。
      return if info_agent_service&.info&.dig('urls', 'streaming_api').blank?

      @listener = @listener_class.new
    end

    # @listener を要するテストの前提ガード。streaming_api を広告する環境（フルスタック）でのみ
    # @listener が構築でき、標準の config プロパティを実アサートする。streaming 未提供の環境
    # （standalone / harness いずれも）では live streaming ではなくこれら config 検証自体が
    # 成立しないため、silent な `return`（fake pass）ではなく可視 omit でスキップする（#4447）。
    # harness の streaming provisioning は chubo2#63。
    def require_listener!
      omit('streaming_api 未提供（Listener を構築できない・harness は chubo2#63）') unless @listener
    end

    def teardown
      @listener_class&.instance_variable_set(:@retry_count, 0)
      Redis.new.del('listener:last_event')
    rescue
      nil
    end

    def test_verify_peer?
      require_listener!
      expected = config["/#{Environment.controller_name}/streaming/verify_peer"]

      assert_boolean(@listener.verify_peer?)
      assert_equal(expected, @listener.verify_peer?)
    end

    def test_root_cert_file
      require_listener!

      assert_path_exist(@listener.root_cert_file)
    end

    def test_keepalive
      require_listener!

      assert_predicate(@listener.keepalive, :positive?)
    end

    def test_underscore
      require_listener!

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
