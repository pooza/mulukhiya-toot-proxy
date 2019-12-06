module MulukhiyaTootProxy
  class TootTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @config = Config.instance
      @account = Account.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_id
      return if Environment.ci?
      assert(@toot.id.positive?)
    end

    def test_account
      return if Environment.ci?
      assert(@toot.account.is_a?(Account))
    end

    def test_text
      return if Environment.ci?
      assert(@toot.text.is_a?(String))
    end

    def test_uri
      return if Environment.ci?
      assert(@toot.uri.is_a?(MastodonURI))
    end

    def test_to_md
      return if Environment.ci?
      assert(@toot.to_md.is_a?(String))
    end
  end
end
