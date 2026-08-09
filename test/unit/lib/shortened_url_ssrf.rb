require 'webmock/test_unit'

module Mulukhiya
  # 短縮 URL の展開が、リダイレクトの各ホップで SSRF allowlist を通ること (#4535)。
  #
  # ShortenedURLHandler は Location だけ見て自前でホップを追う (Ginseng::HTTP の
  # host_validator に任せると最終 URL が取れない) ので、検証もハンドラ側の責務。
  #
  # ⚠ ファイル名を *_handler.rb にしない。TestCase.load が
  # `Handler.create(name).disable?` を評価するため、ハンドラが無効な環境では
  # ケースごと落ち、この回帰テストまで一緒に消える。
  class ShortenedURLSsrfTest < TestCase
    SHORTENED = 'https://t.co/deadbeef'.freeze
    METADATA = 'http://169.254.169.254/latest/meta-data/'.freeze
    PUBLIC_DEST = 'https://www.example.jp/article'.freeze

    def setup
      WebMock.disable_net_connect!
      # sns を渡さないと Handler#initialize が実 SNS サービスを組み立て、
      # Sequel (Postgres) 依存になる。展開処理は SNS を触らないのでダブルで足りる。
      @handler = ShortenedURLHandler.new(sns: Object.new)
      RemoteHost.validator = ->(host) {['t.co', 'www.example.jp'].include?(host)}
    end

    def teardown
      super
      # ⚠ 差し替えたままにすると以後のテストで SSRF ガードが効かなくなる。
      # nil を入れると次の参照で既定 (RemoteHost.public?) が張り直される。
      RemoteHost.validator = nil
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    def resolve(url = SHORTENED)
      return @handler.send(:resolve_redirects, Ginseng::URI.parse(url))
    end

    # 正のケース: 許可ホストへのリダイレクトはこれまでどおり展開される。
    def test_follows_permitted_redirect
      stub_request(:get, SHORTENED).to_return(status: 301, headers: {'Location' => PUBLIC_DEST})
      stub_request(:get, PUBLIC_DEST).to_return(status: 200, body: 'ok')

      assert_equal(PUBLIC_DEST, resolve.to_s)
    end

    # リンクローカル (メタデータサービス) へのリダイレクトは GET しない。
    def test_blocks_redirect_to_link_local_metadata
      stub_request(:get, SHORTENED).to_return(status: 302, headers: {'Location' => METADATA})

      assert_equal(SHORTENED, resolve.to_s)
      assert_not_requested(:get, METADATA)
    end

    # ⚠ GET しないだけでは足りない。弾いた URL を展開結果に採ると、投稿本文が
    # 内部 URL へ書き換わったまま連合に流れる。
    def test_does_not_rewrite_status_to_rejected_url
      stub_request(:get, SHORTENED).to_return(status: 302, headers: {'Location' => METADATA})

      assert_not_include(resolve.to_s, '169.254.169.254')
      assert_true(@handler.errors.any? {|v| v[:message].to_s.include?('Rejected host')})
    end

    # 初段そのものが拒否ホストなら、1 回も GET しない。
    def test_blocks_first_hop
      stub_request(:get, METADATA).to_return(status: 200, body: 'ok')

      assert_equal(METADATA, resolve(METADATA).to_s)
      assert_not_requested(:get, METADATA)
    end

    # ⚠ **検証で通したアドレスを捨てない** (#4524)。ここは自前でホップを追う経路
    # なので、Ginseng::HTTP の host_validator は使えず pinning も自前で渡す。
    # 捨てると GET のたびに名前を引き直し、権威 DNS を握った相手に
    # 「検証は公開 IP・接続は 127.0.0.1」を返される（DNS リバインディング）。
    def test_pins_validated_address_on_every_hop
      addresses = {'t.co' => '203.0.113.1', 'www.example.jp' => '198.51.100.2'}
      RemoteHost.validator = ->(host) {addresses[host]}
      stub_request(:get, SHORTENED).to_return(status: 301, headers: {'Location' => PUBLIC_DEST})
      stub_request(:get, PUBLIC_DEST).to_return(status: 200, body: 'ok')

      assert_equal(['203.0.113.1', '198.51.100.2'], recorded_pins {resolve})
    end

    # 真偽値を返す validator でも壊れないこと（pinning しないだけ）。
    def test_boolean_validator_still_resolves
      stub_request(:get, SHORTENED).to_return(status: 301, headers: {'Location' => PUBLIC_DEST})
      stub_request(:get, PUBLIC_DEST).to_return(status: 200, body: 'ok')

      assert_equal(PUBLIC_DEST, resolve.to_s)
    end

    private

    # PinnedAddressAdapter.pin に渡ったアドレスを順に記録する。
    def recorded_pins
      recorded = []
      original = Ginseng::PinnedAddressAdapter.method(:pin)
      Ginseng::PinnedAddressAdapter.define_singleton_method(:pin) do |options, address|
        recorded.push(address)
        original.call(options, address)
      end
      begin
        yield
      ensure
        Ginseng::PinnedAddressAdapter.define_singleton_method(:pin, original)
      end
      return recorded
    end
  end
end
