module Mulukhiya
  class CustommAPIRenderStorageTest < TestCase
    def setup
      @storage = CustomAPIRenderStorage.new
    end

    def test_create_key
      assert_equal(@storage.create_key({page: 1}), 'custom_api:1')
    end

    def test_get
      assert_kind_of([NilClass, Array], @storage[{page: 1}])
      assert_kind_of([NilClass, Array], @storage['custom_api:1'])
      @storage.clear
      assert_nil(@storage[{pare: 1}])
      assert_nil(@storage['custom_api:1'])
    end
  end
end
