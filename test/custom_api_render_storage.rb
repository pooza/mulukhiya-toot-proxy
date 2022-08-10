module Mulukhiya
  class CustommAPIRenderStorageTest < TestCase
    def disable?
      return true unless CustomAPI.all.present?
      return super
    end

    def setup
      @storage = CustomAPIRenderStorage.new
    end

    def test_create_key
      assert_equal('custom_api:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a', @storage.create_key({}))
      assert_equal('custom_api:e153307215072109187baf0cbc03bc7306dbc57db3d2d5d63f23b50338e140a8', @storage.create_key({name: 'maho_girls'}))
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
