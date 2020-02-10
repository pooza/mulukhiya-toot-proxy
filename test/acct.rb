module Mulukhiya
  class AcctTest < TestCase
    def setup
      @acct = Acct.new('@pooza@example.com')
      @acct_another = Acct.new("@#{@pooza}@#{Environment.domain_name}")
    end

    def test_agent?
      assert_boolean(@acct.agent?)
    end

    def test_valid?
      assert(@acct.valid?)
    end

    def test_username
      assert_equal(@acct.username, 'pooza')
    end

    def test_host
      assert_equal(@acct.host, 'example.com')
    end

    def test_domain_name
      assert_equal(@acct.domain_name, 'example.com')
      assert_nil(@acct_another.domain_name)
    end

    def test_pattern
      assert_kind_of(Regexp, Acct.pattern)
    end
  end
end
