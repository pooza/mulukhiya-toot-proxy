module Mulukhiya
  class AcctTest < TestCase
    def setup
      @acct = Acct.new('@pooza@mstdn.b-shock.org')
    end

    def test_agent?
      assert_boolean(@acct.agent?)
    end

    def test_valid?
      assert(@acct.valid?)
    end

    def test_pattern
      assert_kind_of(Regexp, Acct.pattern)
    end
  end
end
