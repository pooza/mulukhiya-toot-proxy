module MulukhiyaTootProxy
  class AccountTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @account = Account.new(token: Config.instance['/test/token'])
    end

    def test_id
      return if Environment.ci?
      assert(@account.id.is_a?(Integer))
    end

    def test_username
      return if Environment.ci?
      assert(@account.username.is_a?(String))
    end

    def test_params
      return if Environment.ci?
      assert(@account.params.is_a?(Hash))
    end
  end
end
