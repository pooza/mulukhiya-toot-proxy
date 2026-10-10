module Mulukhiya
  # 投稿の取得先ホストの検証（ginseng-fediverse 5.0.0・#4813）。
  #
  # 🔴 自サーバーの URL だけ検証から外す。外す条件は scheme・ホスト・ポートの 3 つとも一致。
  # ホスト名だけで外すと、`http://<自ドメイン>:6379/@a/1` で自サーバーの任意のポートへ要求が出る。
  class StatusHostValidationTest < TestCase
    KEY = "/#{Environment.controller_name}/url".freeze
    SAME_HOST = [
      'http://sns.example.com:6379/@a/1',
      'https://sns.example.com:8443/@a/1',
      'http://sns.example.com/@a/1',
    ].freeze
    OTHER_HOSTS = [
      'https://other.example.com/@a/1',
      'https://sns.example.com.attacker.example/@a/1',
      'http://127.0.0.1:3000/@a/1',
    ].freeze

    def setup
      @saved = config[KEY]
      config[KEY] = 'https://sns.example.com'
    end

    def teardown
      config[KEY] = @saved
    end

    def test_own_origin_is_not_validated
      [TootURI, NoteURI].each do |klass|
        assert_nil(klass.parse('https://sns.example.com/@a/1').host_validator, klass.to_s)
        assert_nil(klass.parse('https://SNS.Example.com:443/@a/1').host_validator, klass.to_s)
      end
    end

    # 🔴 本命。ホスト名が同じでも、ポートか scheme が違えば検証する。
    def test_same_host_on_another_port_or_scheme_is_validated
      [TootURI, NoteURI].each do |klass|
        SAME_HOST.each do |url|
          assert_same(RemoteHost.validator, klass.parse(url).host_validator, "#{klass} #{url}")
        end
      end
    end

    def test_other_hosts_are_validated
      [TootURI, NoteURI].each do |klass|
        OTHER_HOSTS.each do |url|
          assert_same(RemoteHost.validator, klass.parse(url).host_validator, "#{klass} #{url}")
        end
      end
    end

    # ⚠ ポートつき・http の自サーバー（fedi-test-harness の形）も、3 つとも一致なら外す。
    def test_own_origin_with_explicit_port
      config[KEY] = 'http://localhost:3001'

      assert_nil(NoteURI.parse('http://localhost:3001/notes/abc').host_validator)
      assert_same(RemoteHost.validator, NoteURI.parse('http://localhost:6379/notes/abc').host_validator)
      assert_same(RemoteHost.validator, NoteURI.parse('https://localhost:3001/notes/abc').host_validator)
    end

    # ⚠ 設定が読めないときは検証する側へ倒す。
    def test_validates_when_own_url_is_unavailable
      config[KEY] = nil

      assert_same(RemoteHost.validator, TootURI.parse('https://sns.example.com/@a/1').host_validator)
    end
  end
end
