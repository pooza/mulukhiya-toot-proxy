module Mulukhiya
  # トークンを持たないアカウントから webhook URL が出ないこと (#4487)。
  #
  # {sns:, token: nil, salt:} の SHA256 は「URL の形をしているのに誰のものでもない」
  # 幽霊 URL になる。find_token_by_digest は oauth_access_tokens を舐めて
  # token.webhook_digest（トークン文字列から作った値）と突き合わせるので、nil から
  # 作った値に一致するレコードは存在しない。**設定はできたのに何も起きない**という
  # 静かな失敗になるため、URL を出す前に落とす。
  #
  # DB を必要としないよう、UserConfig ではなく sns.token を直接差し替えて検証する。
  class WebhookTokenGuardTest < TestCase
    # valid? / webhook_digest だけを持つ AccessToken のダブル。
    #
    # valid? は **是正前の `to_s.empty?`** を敢えて再現する。blank? に直した実装
    # (#4487) が将来また緩んでも、find_token_by_digest 側の堅牢化だけで走査が
    # 続くことをこのテストで担保するため。
    TokenDouble = Struct.new(:token) do
      def valid?
        return !token.to_s.empty?
      end

      def webhook_digest
        return Webhook.create_digest(Ginseng::URI.parse('https://example.com'), token)
      end
    end

    # UserConfig も SNS サービスも DB を引くので、digest / uri が必要とする
    # token / uri / create_uri だけを持つダブルを使う。
    SNSDouble = Struct.new(:token) do
      def uri
        return Ginseng::URI.parse('https://example.com')
      end

      def create_uri(path)
        return Ginseng::URI.parse("https://example.com#{path}")
      end
    end

    def setup
      @uri = Ginseng::URI.parse('https://example.com')
    end

    # 実際にブロックすること（正のケース）。
    def test_create_digest_rejects_blank_token
      [nil, '', '   '].each do |token|
        assert_raise(Ginseng::ConfigError, "token=#{token.inspect} を拒否していない") do
          Webhook.create_digest(@uri, token)
        end
      end
    end

    def test_create_digest_accepts_token
      digest = Webhook.create_digest(@uri, 'valid_token')

      assert_match(/\A[0-9a-f]{64}\z/, digest)
    end

    # ⚠ digest の値そのものは webhook URL の一部なので、ガードの追加で変わっては
    # いけない（変わると tomato-shrieker 等の外部連携が全部切れる）。
    def test_guard_does_not_change_digest_value
      token = 'test_token_for_digest_stability'
      expected = {
        sns: @uri.to_s,
        token:,
        salt: (Config.instance['/crypt/salt'] rescue Crypt.password),
      }.to_json.sha256

      assert_equal(expected, Webhook.create_digest(@uri, token))
    end

    def test_digest_rejects_blank_token
      hook = build_webhook(nil)

      assert_not_predicate(hook, :available?)
      assert_raise(Ginseng::ConfigError) {hook.digest}
      assert_raise(Ginseng::ConfigError) {hook.uri}
    end

    def test_digest_accepts_token
      hook = build_webhook('valid_token')

      assert_predicate(hook, :available?)
      assert_match(/\A[0-9a-f]{64}\z/, hook.digest)
      assert_kind_of(Ginseng::URI, hook.uri)
    end

    # ⚠ ガードの副作用で「正しい webhook URL が見つからなくなる」ことがあってはならない。
    #
    # webhook_digest は空トークンで raise するので、壊れた行が走査の途中にあると
    # 例外が each の外へ出て、その行より**後ろ**の正しい行に辿り着けなくなる。
    # 壊れた行は next で送り、走査は最後まで続ける（PR #4522 への Codex P2 指摘）。
    def test_find_token_by_digest_skips_broken_row_and_keeps_scanning
      good = TokenDouble.new('valid_token')
      rows = [{id: 1}, {id: 2}]
      # 1 行目は valid? を通るのに webhook_digest で落ちる行（空白トークン等）。
      tokens = {1 => TokenDouble.new('   '), 2 => good}

      with_webhook_tokens(rows, tokens) do
        assert_equal(good, Webhook.find_token_by_digest(good.webhook_digest))
      end
    end

    def test_find_token_by_digest_returns_nil_when_nothing_matches
      rows = [{id: 1}]
      tokens = {1 => TokenDouble.new('   ')}

      with_webhook_tokens(rows, tokens) do
        assert_nil(Webhook.find_token_by_digest('deadbeef'))
      end
    end

    private

    def with_webhook_tokens(rows, tokens)
      Postgres.singleton_class.alias_method(:exec_without_stub, :exec)
      Environment.singleton_class.alias_method(:access_token_class_without_stub, :access_token_class)
      Postgres.define_singleton_method(:exec) {|name, _params = {}| name == :webhook_tokens ? rows : []}
      token_class = Class.new do
        define_singleton_method(:[]) {|id| tokens[id]}
      end
      Environment.define_singleton_method(:access_token_class) {token_class}
      yield
    ensure
      Postgres.singleton_class.alias_method(:exec, :exec_without_stub)
      Environment.singleton_class.alias_method(:access_token_class, :access_token_class_without_stub)
    end

    def build_webhook(token)
      hook = Webhook.allocate
      hook.instance_variable_set(:@sns, SNSDouble.new(token))
      return hook
    end
  end
end
