module Mulukhiya
  class SNSMethodsTest < TestCase
    def test_create_status_uri
      assert_nil(SNSMethods.create_status_uri('https://www.google.co.jp'))
      assert_nil(SNSMethods.create_status_uri('hoge'))
      assert_nil(SNSMethods.create_status_uri(nil))
      assert_kind_of(TootURI, SNSMethods.create_status_uri('https://st.mstdn.b-shock.org/web/statuses/106057223567166956'))
      assert_kind_of(NoteURI, SNSMethods.create_status_uri('https://dev.mis.b-shock.org/notes/8kjdew1qgd'))
    end
  end
end
