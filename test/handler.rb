module Mulukhiya
  class HandlerTest < TestCase
    def test_names
      assert_kind_of(Set, Handler.names)
    end

    def test_search
      assert_kind_of(Set, Handler.search(/amazon/))
    end
  end
end
