require 'webmock/test_unit'

module Mulukhiya
  # 番組表・読み辞書の remote fetch が、リダイレクト先まで含めて SSRF allowlist を
  # 通ることの回帰テスト (#4410)。
  #
  # 初段のホストだけ検証しても HTTParty がリダイレクトを追ってしまうため、
  # 「見せかけの安全」になっていた。検証は Ginseng::HTTP の host_validator が
  # 各ホップで行う（ginseng-core 1.15.29）。
  class ProgramFetcherSsrfTest < TestCase
    GAS = 'https://script.google.com/macros/s/deadbeef/exec'.freeze
    GAS_CONTENT = 'https://script.googleusercontent.com/macros/echo'.freeze
    METADATA = 'http://169.254.169.254/latest/meta-data/'.freeze

    def setup
      WebMock.disable_net_connect!
      @http = HTTP.new
    end

    def teardown
      super
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    def validator(*allowed)
      return ->(host) {allowed.include?(host)}
    end

    # GAS は正規に 302 を返す。追従を切ると番組表の取得自体が壊れる。
    def test_follows_legitimate_gas_redirect
      stub_request(:get, GAS).to_return(status: 302, headers: {'Location' => GAS_CONTENT})
      stub_request(:get, GAS_CONTENT).to_return(status: 200, body: '{"a":{}}')

      response = @http.get(GAS, host_validator: validator('script.google.com', 'script.googleusercontent.com'))

      assert_equal(200, response.code)
    end

    # リダイレクト先が内部ホストなら、そこへ実リクエストを出さずに落とす。
    def test_blocks_redirect_to_link_local_metadata
      stub_request(:get, GAS).to_return(status: 302, headers: {'Location' => METADATA})

      assert_raise(Ginseng::GatewayError) do
        @http.get(GAS, host_validator: validator('script.google.com'))
      end
      assert_not_requested(:get, METADATA)
    end

    # RemoteHost.validator が実際に内部アドレスを弾く callable であること。
    def test_remote_host_validator_rejects_private_address
      assert_false(RemoteHost.validator.call('127.0.0.1'))
      assert_false(RemoteHost.validator.call('localhost'))
      assert_false(RemoteHost.validator.call(''))
    end

    # Content-Length のプリフライト (HEAD) も同じ allowlist を通ること (#4523)。
    # GET だけ守っても、その 1 行上で無検証の HEAD が飛ぶなら SSRF 対策にならない。
    # 拒否されたホストへは **HEAD も GET も出ない**ことを、実リクエストの不在で見る。
    def test_program_fetcher_blocks_head_preflight_to_internal_host
      original = config['/program/urls']
      config['/program/urls'] = [METADATA]

      assert_nil(ProgramFetcher.new.fetch)
      assert_not_requested(:head, METADATA)
      assert_not_requested(:get, METADATA)
    ensure
      config['/program/urls'] = original if defined?(original)
    end

    def test_pronunciation_dictionary_blocks_head_preflight_to_internal_host
      original = config['/word_suggest/urls']
      config['/word_suggest/urls'] = [METADATA]

      assert_nil(PronunciationDictionary.new.send(:fetch_remote))
      assert_not_requested(:head, METADATA)
      assert_not_requested(:get, METADATA)
    ensure
      config['/word_suggest/urls'] = original if defined?(original)
    end

    # HEAD のリダイレクト先が内部ホストでも、そこへは飛ばない。
    def test_blocks_head_redirect_to_link_local_metadata
      stub_request(:head, GAS).to_return(status: 302, headers: {'Location' => METADATA})

      assert_raise(Ginseng::GatewayError) do
        @http.head(GAS, host_validator: validator('script.google.com'))
      end
      assert_not_requested(:head, METADATA)
    end
  end
end
