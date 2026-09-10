module Mulukhiya
  # `Listener#root_cert_file` が **実在するパスしか返さない**こと (#4586)。
  #
  # ⚠⚠ **ここに渡る値は env ではなく `ca_file` 相当。**`SSL_CERT_FILE` として
  # 読まれるぶんには存在しないパスは無害だが、`tls[:root_cert_file]` へ渡すと
  # `SSL_CTX_load_verify_file` が即座に `OpenSSL::SSL::SSLError` で落ちる。
  #
  # ⚠ `Listener#initialize` は実際に `Faye::WebSocket::Client` を張るので、
  # ここでは `allocate` でインスタンスだけ作る（`root_cert_file` は public）。
  class ListenerRootCertTest < TestCase
    def setup
      @listener = Listener.allocate
      @key = @listener.root_cert_file_key
      @config = config[@key] rescue nil
      @env = ENV.fetch('SSL_CERT_FILE', nil)
    end

    def teardown
      config[@key] = @config
      ENV['SSL_CERT_FILE'] = @env
      ENV.delete('SSL_CERT_FILE') if @env.nil?
    end

    # 🔴 **本体。**設定に存在しないパスが入っていても、そのまま返さない。
    def test_missing_configured_path_is_dropped
      config[@key] = '/nonexistent/cacert.pem'

      assert_nil(@listener.root_cert_file)
    end

    # 🔴 **本体その 2。**設定が無いときのフォールバック（env）も同じ扱い。
    # ⚠ **これが #4586 の実害の入口**だった。
    def test_missing_env_path_is_dropped
      config[@key] = nil
      assert_raises(Ginseng::ConfigError) {config[@key]}
      ENV['SSL_CERT_FILE'] = '/nonexistent/cacert.pem'

      assert_nil(@listener.root_cert_file)
    end

    # 実在するなら設定値をそのまま返す（機能を殺していないこと）。
    def test_existing_configured_path_is_kept
      config[@key] = __FILE__

      assert_equal(__FILE__, @listener.root_cert_file)
    end

    # 設定が無くても env が実在すればそちらを使う。
    def test_existing_env_path_is_kept
      config[@key] = nil
      ENV['SSL_CERT_FILE'] = __FILE__

      assert_equal(__FILE__, @listener.root_cert_file)
    end

    # 設定も env も無ければ nil＝ OS の CA ストアに倒れる。⚠ `verify_peer` は効く。
    def test_nil_without_config_and_env
      config[@key] = nil
      ENV.delete('SSL_CERT_FILE')

      assert_nil(@listener.root_cert_file)
    end

    # 空文字は「未設定」と同じ扱い。File.exist?('') は false だが、
    # ここを通す前に落として error ログを出さない。
    def test_blank_is_not_an_error
      config[@key] = nil
      ENV['SSL_CERT_FILE'] = ''
      logged = capture_errors

      assert_nil(@listener.root_cert_file)
      # ⚠ 戻り値の nil だけだと、`blank?` のガードを消しても
      # （`File.exist?('')` が false で）通ってしまう。見るのは「error を出さない」こと。
      assert_empty(logged, '空文字で error ログを出している')
    end

    # 逆に、存在しないパスは黙って落とさない（運用者が気付けるように error を出す）。
    def test_missing_path_is_logged
      config[@key] = '/nonexistent/cacert.pem'
      logged = capture_errors

      @listener.root_cert_file

      assert_equal(1, logged.length)
    end

    private

    def capture_errors
      logged = []
      double = Object.new
      double.define_singleton_method(:error) {|payload| logged.push(payload)}
      @listener.define_singleton_method(:logger) {double}
      return logged
    end
  end
end
