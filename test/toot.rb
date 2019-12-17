module MulukhiyaTootProxy
  class TootTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @account = Environment.account_class.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_id
      assert(@toot.id.positive?)
    end

    def test_account
      assert(@toot.account.is_a?(Environment.account_class))
    end

    def test_text
      assert(@toot.text.is_a?(String))
    end

    def test_uri
      assert(@toot.uri.is_a?(MastodonURI))
    end

    def test_to_md
      assert(@toot.to_md.is_a?(String))
    end
  end
end
