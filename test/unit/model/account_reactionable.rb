module Mulukhiya
  # 受け手のサーバーが絵文字リアクションを表示できるか（`ReplyReactionHandler` が返信を投稿しない条件）。
  # ⚠ nodeinfo の `software.name` で設定を引く。Akkoma は `akkoma` と名乗る（#4884）。DB に繋がない。
  class AccountReactionableTest < TestCase
    # ⚠ 本物のアカウントと同じく `Package` も入れる。無いと `config` が NoMethodError になり、
    # `reactionable?` の `rescue nil` に握られて常に false になる。
    FakeAccount = Struct.new(:acct) do
      include Package
      include AccountMethods
    end

    HOST = 'example.com'.freeze

    def setup
      WebMock.disable_net_connect!
      @account = FakeAccount.new(Acct.new("@someone@#{HOST}"))
    end

    def stub_software(name, capabilities = nil)
      nodeinfo = "https://#{HOST}/nodeinfo/2.0"
      stub_request(:get, "https://#{HOST}/.well-known/nodeinfo")
        .to_return(json({links: [{rel: 'http://nodeinfo.diaspora.software/ns/schema/2.0', href: nodeinfo}]}))
      stub_request(:get, nodeinfo).to_return(json({software: {name:, version: '1.0.0'}}))
      stub_request(:get, "https://#{HOST}/api/v1/instance")
        .to_return(json({fedibird_capabilities: capabilities}.compact))
    end

    def json(body)
      return {status: 200, body: body.to_json, headers: {'Content-Type' => 'application/json'}}
    end

    def test_akkoma
      stub_software('akkoma')

      assert_predicate(@account, :reactionable?)
    end

    def test_pleroma
      stub_software('pleroma')

      assert_predicate(@account, :reactionable?)
    end

    def test_mastodon
      stub_software('mastodon')

      assert_false(@account.reactionable?)
    end

    def test_fedibird
      stub_software('fedibird', ['emoji_reaction'])

      assert_predicate(@account, :reactionable?)
    end
  end
end
