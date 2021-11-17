module Mulukhiya
  class MediaCatalogRenderStorageTest < TestCase
    def setup
      @storage = MediaCatalogRenderStorage.new
    end

    def test_create_key
      assert_equal(@storage.create_key({page: 1}), 'media_catalog:1')
      assert_equal('media_catalog:1', 'media_catalog:1')
    end

    def test_get
      assert_kind_of([NilClass, Array], @storage[{page: 1}])
      assert_kind_of([NilClass, Array], @storage['media_catalog:1'])
      @storage.clear
      assert_nil(@storage[{pare: 1}])
      assert_nil(@storage['media_catalog:1'])
    end
  end
end
