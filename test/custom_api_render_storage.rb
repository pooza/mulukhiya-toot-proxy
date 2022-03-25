module Mulukhiya
  class CustommAPIRenderStorageTest < TestCase
    def setup
      @storage = CustomAPIRenderStorage.new
    end

    def test_create_key
      assert_equal('custom_api:24445177', @storage.create_key({}))
      assert_equal('custom_api:1338115969', @storage.create_key({name: 'maho_girls'}))
    end

    def test_get
      assert_kind_of([NilClass, Array], @storage[{}])
      assert_kind_of([NilClass, Array], @storage[{name: 'maho_girls'}])
      @storage.clear
      assert_nil(@storage[{}])
      assert_nil(@storage[{name: 'maho_girls'}])
    end
  end
end
