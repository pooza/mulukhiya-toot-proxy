module MulukhiyaTootProxy
  class StatusTest < TestCase
    def setup
      @account = Environment.test_account
      @status = @account.recent_status
    end

    def test_id
      assert(@status.id.present?)
    end

    def test_account
      assert_kind_of(Environment.account_class, @status.account)
    end

    def test_attachments
      @status.attachments.each do |attachment|
        assert_kind_of(Environment.attachment_class, attachment)
        pp attachment
      end
    end

    def test_text
      assert_kind_of(String, @status.text)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @status.uri)
    end

    def test_to_md
      assert_kind_of(String, @status.to_md)
    end
  end
end
