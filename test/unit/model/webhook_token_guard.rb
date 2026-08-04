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

    private

    def build_webhook(token)
      hook = Webhook.allocate
      hook.instance_variable_set(:@sns, SNSDouble.new(token))
      return hook
    end
  end
end
