module Mulukhiya
  class NoteURITest < TestCase
    def setup
      @uri = NoteURI.parse(account.recent_status.uri)
    end

    test 'テスト用投稿の有無' do
      assert(account.recent_status)
    end

    def test_id
      return unless @uri
      assert_kind_of(String, @uri.id)
    end

    def test_service
      return unless @uri
      assert_kind_of(sns_class, @uri.service)
    end

    def test_to_md
      return unless @uri
      assert_kind_of(String, @uri.to_md)
    end
  end
end
