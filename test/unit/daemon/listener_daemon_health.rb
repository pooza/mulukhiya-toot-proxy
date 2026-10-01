module Mulukhiya
  # ListenerDaemon.health が pid ファイルをどう読むか (#4635 の 5・6 件目)。
  #
  # ⚠ ListenerDaemonTest と分けてあるのは、あちらが「streaming の使える環境か」で
  # 丸ごと disable になるから。ここで見るのは pid ファイルの読み方だけで、環境に依らない。
  class ListenerDaemonHealthTest < TestCase
    def setup
      @dir = Dir.mktmpdir
      @pid_path = File.join(@dir, 'ListenerDaemon.pid')
      @stubs = {}
      path = @pid_path
      stub(:pid_path) {path}
      stub(:check_streaming_endpoint) {nil}
    end

    def teardown
      @stubs.each do |name, original|
        if original
          ListenerDaemon.define_singleton_method(name, original)
        else
          ListenerDaemon.singleton_class.send(:remove_method, name)
        end
      end
      FileUtils.rm_rf(@dir)
    end

    def test_live_pid_is_ok
      File.write(@pid_path, Process.pid.to_s)

      assert_equal('OK', ListenerDaemon.health[:status])
    end

    # ⚠ **pid ファイルが無ければ pgrep へ倒す。**`exist?` → `read` の間に消えた
    # （デーモン自身の TERM trap が消した直後）場合も同じ経路を通ること。
    # 以前は `Errno::ENOENT` が総括 rescue に落ち、pgrep を試さずに NG だった。
    def test_missing_pid_file_falls_back_to_pgrep
      stub(:system) {|*| true}

      assert_equal('OK', ListenerDaemon.health[:status])
    end

    def test_missing_pid_file_without_process_is_ng
      stub(:system) {|*| false}
      health = ListenerDaemon.health

      assert_equal('NG', health[:status])
      assert_equal('listener process not found', health[:error])
    end

    # ⚠⚠ **壊れた pid ファイルを OK と言わない。**空・切り詰め・非数値だと `to_i` が 0 に
    # なり、`Process.kill(0, 0)` は自プロセスグループへの存在確認として成功する。
    def test_broken_pid_file_is_ng
      ['', 'garbage', "\n"].each do |content|
        File.write(@pid_path, content)

        assert_equal('NG', ListenerDaemon.health[:status], "pid ファイルが #{content.inspect}")
      end
    end

    private

    def stub(name, &)
      unless @stubs.key?(name)
        @stubs[name] = ListenerDaemon.singleton_methods(false).include?(name) ? ListenerDaemon.method(name) : nil
      end
      ListenerDaemon.define_singleton_method(name, &)
    end
  end
end
