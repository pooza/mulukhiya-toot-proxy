module Mulukhiya
  class StatusTest < TestCase
    def setup
      @status = account.recent_status
    end

    def test_initialize
      assert(@status)
    end

    def test_id
      return unless @status

      assert(@status.id.present?)
    end

    def test_to_h
      return unless @status

      assert_kind_of(Hash, @status.to_h)
    end

    def test_account
      return unless @status

      assert_kind_of(account_class, @status.account)
    end

    def test_attachments
      return unless @status

      @status.attachments.each do |attachment|
        assert_kind_of([attachment_class, Hash], attachment)
      end
    end

    def test_local?
      return unless @status

      assert_boolean(@status.local?)
    end

    def test_visible?
      return unless @status

      assert_boolean(@status.visible?)
    end

    def test_text
      return unless @status

      assert_kind_of(String, @status.text)
    end

    def test_uri
      return unless @status

      assert_kind_of(Ginseng::URI, @status.uri)
    end

    def test_public_uri
      return unless @status

      assert_kind_of(Ginseng::URI, @status.public_uri)
    end

    def test_to_md
      return unless @status

      assert_kind_of(String, @status.to_md)
    end
  end
end
