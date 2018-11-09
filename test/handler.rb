module MulukhiyaTootProxy
  class HandlerTest < Test::Unit::TestCase
    def test_all
      Handler.all do |handler|
        assert_true(handler.is_a?(Handler))
      end
    end
  end
end
