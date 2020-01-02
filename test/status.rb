module MulukhiyaTootProxy
  class StatusTest < TestCase
    def setup
      @config = Config.instance
      @account = Environment.account_class.get(token: @config['/test/token'])
      @status = @account.recent_status
    end

    def test_id
      assert(@status.id.positive?)
    end

    def test_account
      assert(@status.account.is_a?(Environment.account_class))
    end

    def test_text
      assert(@status.text.is_a?(String))
    end

    def test_uri
      assert(@status.uri.is_a?(MastodonURI))
    end

    def test_to_md
      assert(@status.to_md.is_a?(String))
    end
  end
end
