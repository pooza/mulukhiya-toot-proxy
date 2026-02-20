module Mulukhiya
  class NoteURITest < TestCase
    def disable?
      return true unless Environment.note?
      return true unless account
      return super
    end

    def setup
      return if disable?
      @uri = NoteURI.parse(account.recent_status.uri)
    end

    test 'テスト用投稿の有無' do
      assert_not_nil(account.recent_status)
    end

    def test_id
      assert_kind_of(String, @uri.id) if @uri
    end

    def test_service
      assert_kind_of(sns_class, @uri.service) if @uri
    end

    def test_to_md
      assert_kind_of(String, @uri.to_md) if @uri
    end
  end
end
