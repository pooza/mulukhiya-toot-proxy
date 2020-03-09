module Mulukhiya
  class NoteURITest < TestCase
    def setup
      @uri = NoteURI.parse('https://dev.dol.b-shock.org/notes/8210l8qhnc')
    end

    def test_id
      assert_equal(@uri.id, '8210l8qhnc')
    end

    def test_service
      assert_kind_of(Environment.sns_class, @uri.service)
    end
  end
end
