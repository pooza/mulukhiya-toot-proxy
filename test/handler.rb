module Mulukhiya
  class HandlerTest < TestCase
    def test_names
      assert_kind_of(Array, Handler.names)
    end

    def test_search
      assert_kind_of(Array, Handler.search(/twitter/))
      assert_kind_of(Array, Handler.search(/amazon/))
    end
  end
end
