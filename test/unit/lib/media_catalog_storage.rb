require 'securerandom'

module Mulukhiya
  class MediaCatalogStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = MediaCatalogStorage.new
      @key = "test_#{SecureRandom.hex(8)}"
    end

    def test_prefix
      assert_equal('media_catalog', @storage.prefix)
    end

    def test_get_set
      assert_nil(@storage.get(@key))

      data = {items: [{id: 1, name: 'test.jpg'}], has_next: false, page: 1}
      @storage.set(@key, data)
      result = @storage.get(@key)

      assert_kind_of(Hash, result)
      assert_equal(1, result[:items].size)
      refute(result[:has_next])

      @storage.unlink(@key)

      assert_nil(@storage.get(@key))
    end

    def test_ttl_page1
      @storage.set('page:1:person:0', {items: [], has_next: false})
      ttl = @storage.ttl('page:1:person:0')

      assert_operator(ttl, :<=, MediaCatalogStorage::PAGE1_TTL)
      assert_operator(ttl, :>, 0)

      @storage.unlink('page:1:person:0')
    end

    def test_ttl_page2
      @storage.set('page:2:person:0', {items: [], has_next: false})
      ttl = @storage.ttl('page:2:person:0')

      assert_operator(ttl, :<=, MediaCatalogStorage::DEFAULT_TTL)
      assert_operator(ttl, :>, MediaCatalogStorage::PAGE1_TTL)

      @storage.unlink('page:2:person:0')
    end
  end
end
