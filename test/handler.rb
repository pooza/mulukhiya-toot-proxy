module Mulukhiya
  class HandlerTest < TestCase
    def test_names
      assert_kind_of(Set, Handler.names)
    end

    def test_search
      assert_kind_of(Set, Handler.search(/amazon/))
    end

    def test_timeout
      Handler.names.each do |name|
        next unless handler = Handler.create(name)
        assert_predicate(handler.timeout, :positive?)
      end
    end

    def test_summary
      handler = Handler.create(:default_tag)
      handler.handle_toot('テスト', {})
      assert_kind_of(Hash, handler.summary)
    end
  end
end
