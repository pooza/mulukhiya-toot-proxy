module MulukhiyaTootProxy
  class TaggingResourceTest < Test::Unit::TestCase
    def test_all
      TaggingResource.all do |resource|
        assert(resource.is_a?(TaggingResource))
      end
    end

    def test_uri
      TaggingResource.all do |resource|
        assert(resource.uri.is_a?(Addressable::URI))
      end
    end

    def test_fetch
      TaggingResource.all do |resource|
        assert(resource.fetch.present?)
      end
    end
  end
end
