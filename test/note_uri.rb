module Mulukhiya
  class NoteURITest < TestCase
    def setup
      @uri = NoteURI.parse(account.recent_status.uri)
      @uri_misskey = NoteURI.parse('https://dev.mis.b-shock.org/notes/8kjdew1qgd')
      @uri_meisskey = NoteURI.parse('https://dev.mei.b-shock.org/notes/7178ca821b99d7996c6c7fe4')
    end

    def test_id
      assert_kind_of(String, @uri.id)
    end

    def test_service
      assert_kind_of(sns_class, @uri.service)
    end

    def test_to_md
      assert_kind_of(String, @uri.to_md)
    end

    def test_subject
      assert(@uri_misskey.subject.start_with?('カレーうどん'))
      assert(@uri_meisskey.subject.start_with?('カレー将軍'))
    end
  end
end
