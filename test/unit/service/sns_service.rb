module Mulukhiya
  class SNSServiceTest < TestCase
    def disable?
      return true unless test_token
      return super
    end

    def setup
      return if disable?
      @sns = sns_class.new
    end

    def test_info
      assert_kind_of(Hash, @sns.info)

      # node_name / maintainer_name は nodeinfo(metadata) 由来。harness の Mastodon は
      # nodeinfo href を https://localhost:3000 で広告するが 3000 は平文 http のみ提供のため
      # 取得に失敗し info が空 {} になる（node_name も nil に倒れる）。harness 駆動時のみ
      # 明示 omit する（silent skip ではない）。非 harness（本番等）で node_name が nil なのは
      # 実退行なので下の assert で落とす。harness 側の nodeinfo 到達性改善は chubo2#63。
      omit('harness で nodeinfo を取得できない（https/http 不整合・chubo2#63）') \
        if harness? && @sns.node_name.nil?

      assert_kind_of(String, @sns.node_name)

      # maintainer は nodeinfo の `metadata.maintainer.name` だが、**これを出すのは
      # Misskey だけ**。Mastodon は NodeInfo::Serializer#metadata が nodeName /
      # nodeDescription しか返さず（フォークの pooza/mastodon も同じ）、設定でも
      # 生やせないため、Mastodon で nil なのは実装どおりで退行ではない (#4552)。
      return unless Environment.misskey_type?

      assert_kind_of(String, @sns.maintainer_name)
    end

    def test_account
      assert_kind_of(account_class, @sns.account)
    end

    def test_access_token
      assert_kind_of(access_token_class, @sns.access_token)
    end

    def test_create_status_uri
      assert_nil(@sns.create_status_uri('https://www.google.co.jp'))
      assert_nil(@sns.create_status_uri('hoge'))
      assert_nil(@sns.create_status_uri(nil))
      assert_kind_of(TootURI, @sns.create_status_uri('https://st.mstdn.b-shock.org/web/statuses/106057223567166956'))
      assert_kind_of(NoteURI, @sns.create_status_uri('https://dev.mis.b-shock.org/notes/8kjdew1qgd'))
    end
  end
end
