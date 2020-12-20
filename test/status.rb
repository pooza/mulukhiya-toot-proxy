module Mulukhiya
  class StatusTest < TestCase
    def setup
      @account = Environment.test_account
      @status = @account.recent_status
    end

    def test_id
      assert(@status.id.present?)
    end

    def test_to_h
      assert_kind_of(Hash, @status.to_h)
    end

    def test_account
      assert_kind_of(Environment.account_class, @status.account)
    end

    def test_attachments
      @status.attachments.each do |attachment|
        assert_kind_of([Environment.attachment_class, Hash], attachment)
      end
    end

    def test_local?
      assert_boolean(@status.local?)
    end

    def test_visible?
      assert_boolean(@status.visible?)
    end

    def test_text
      assert_kind_of(String, @status.text)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @status.uri)
    end

    def test_public_uri
      assert_kind_of(Ginseng::URI, @status.public_uri)
    end

    def test_to_md
      assert_kind_of(String, @status.to_md)
    end
  end
end
