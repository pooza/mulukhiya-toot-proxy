module Mulukhiya
  class NoteURITest < TestCase
    def setup
      @uri = NoteURI.parse(Environment.test_account.recent_note.uri)
    end

    def test_id
      assert_kind_of(String, @uri.id)
    end

    def test_service
      assert_kind_of(Environment.sns_class, @uri.service)
    end

    def test_to_md
      assert_kind_of(String, @uri.to_md)
    end
  end
end
