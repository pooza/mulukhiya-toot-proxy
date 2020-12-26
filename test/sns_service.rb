module Mulukhiya
  class SNSServiceTest < TestCase
    def setup
      @sns = Environment.sns_class.new
    end

    def test_info
      assert_kind_of(Hash, @sns.info)
    end
  end
end
