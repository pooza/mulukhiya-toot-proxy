module MulukhiyaTootProxy
  class TootTest < Test::Unit::TestCase
    def setup
      return unless Postgres.config?
      @config = Config.instance
      @account = Environment.account_class.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_id
      return unless Postgres.config?
      assert(@toot.id.positive?)
    end

    def test_account
      return unless Postgres.config?
      assert(@toot.account.is_a?(Account))
    end

    def test_text
      return unless Postgres.config?
      assert(@toot.text.is_a?(String))
    end

    def test_uri
      return unless Postgres.config?
      assert(@toot.uri.is_a?(MastodonURI))
    end

    def test_to_md
      return unless Postgres.config?
      assert(@toot.to_md.is_a?(String))
    end
  end
end
