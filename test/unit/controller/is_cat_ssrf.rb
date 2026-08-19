require 'webmock/test_unit'

module Mulukhiya
  # POST /account/is_cat の webfinger / actor 取得の SSRF ガード (#4576)。
  #
  # ⚠ **有効なトークンさえあれば誰でも撃てる経路**（権限チェックは
  # `raise AuthError unless sns.account` だけ）。しかも `accts` は最大 50 件で
  # `Parallel.each` なので、1 リクエストで 50 ホストへ並列に飛ぶ。
  class IsCatSSRFTest < TestCase
    ACCT = 'a@attacker.example'.freeze
    WEBFINGER = 'https://attacker.example/.well-known/webfinger?resource=acct:a@attacker.example'.freeze
    INTERNAL = 'http://127.0.0.1:9200/'.freeze

    def setup
      WebMock.disable_net_connect!
      # ⚠ 差し替えたら teardown で必ず戻す。残すと以後のテストで SSRF ガードが
      # 効かなくなり「守れているつもりの緑」になる。
      @original_validator = RemoteHost.validator
    end

    def teardown
      super
      RemoteHost.validator = @original_validator
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    # 拒否ホストは **1 バイトも取りに行かない**。事前判定が効いていること。
    def test_rejected_host_is_never_requested
      RemoteHost.validator = ->(_host) {}
      stub_request(:get, WEBFINGER).to_return(status: 200, body: '{}')

      assert_nil(fetch_actor)
      assert_not_requested(:get, WEBFINGER)
    end

    # ⚠ **本命の回帰。**host_validator を渡していないと HTTParty 既定の追従で
    # 内部サービスへ到達できていた（検証済みホストの裏から回られる）。
    def test_redirect_to_internal_host_is_blocked
      RemoteHost.validator = ->(host) {host == 'attacker.example' ? '93.184.216.34' : nil}
      stub_request(:get, WEBFINGER).to_return(status: 302, headers: {'Location' => INTERNAL})
      internal = stub_request(:get, INTERNAL).to_return(status: 200, body: '{}')

      assert_nil(fetch_actor)
      assert_not_requested(internal)
    end

    # webfinger が返した actor の href も検証する（別ホストを指しうる）。
    def test_actor_host_is_validated
      RemoteHost.validator = ->(host) {host == 'attacker.example' ? '93.184.216.34' : nil}
      stub_request(:get, WEBFINGER).to_return(
        status: 200,
        body: {links: [{type: 'application/activity+json', href: 'https://internal.example/actor'}]}.to_json,
        headers: {'Content-Type' => 'application/jrd+json'},
      )
      actor = stub_request(:get, 'https://internal.example/actor').to_return(status: 200, body: '{}')

      assert_nil(fetch_actor)
      assert_not_requested(actor)
    end

    # 正常系まで塞いでいないこと。
    def test_allowed_host_is_fetched
      RemoteHost.validator = ->(_host) {'93.184.216.34'}
      stub_request(:get, WEBFINGER).to_return(
        status: 200,
        body: {links: [{type: 'application/activity+json', href: 'https://attacker.example/actor'}]}.to_json,
        headers: {'Content-Type' => 'application/jrd+json'},
      )
      stub_request(:get, 'https://attacker.example/actor').to_return(
        status: 200,
        body: {isCat: true}.to_json,
        headers: {'Content-Type' => 'application/activity+json'},
      )

      assert_true(fetch_actor['isCat'])
    end

    private

    def fetch_actor
      controller = APIController.new!
      return controller.send(:fetch_actor, HTTP.new, Ginseng::Fediverse::Acct.new(ACCT))
    end
  end
end
