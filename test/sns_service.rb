module Mulukhiya
  class SNSServiceTest < TestCase
    def setup
      @sns = sns_class.new
    end

    def test_info
      assert_kind_of(Hash, @sns.info)
      assert_kind_of(String, @sns.maintainer_name)
      assert_kind_of(String, @sns.node_name)
      assert(@sns.max_post_text_length.positive?)
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
