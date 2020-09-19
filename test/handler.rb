module Mulukhiya
  class HandlerTest < TestCase
    def test_names
      pp Handler.names
      assert_kind_of(Array, Handler.names)
    end
  end
end
