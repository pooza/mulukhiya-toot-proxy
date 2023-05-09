module Mulukhiya
  class NoteURITest < TestCase
    def disable?
      return true unless Environment.note?
      return super
    end

    def setup
      @uri = NoteURI.parse(account.recent_status.uri)
    end

    test 'テスト用投稿の有無' do
      assert_not_nil(account.recent_status)
    end

    def test_id
      skip unless @uri

      assert_kind_of(String, @uri.id)
    end

    def test_service
      skip unless @uri

      assert_kind_of(sns_class, @uri.service)
    end

    def test_to_md
      skip unless @uri

      assert_kind_of(String, @uri.to_md)
    end
  end
end
