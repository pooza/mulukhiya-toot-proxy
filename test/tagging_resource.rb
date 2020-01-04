module MulukhiyaTootProxy
  class TaggingResourceTest < TestCase
    def test_all
      TaggingResource.all do |resource|
        assert_kind_of(TaggingResource, resource)
      end
    end

    def test_uri
      TaggingResource.all do |resource|
        assert_kind_of(Ginseng::URI, resource.uri)
      end
    end

    def test_fetch
      TaggingResource.all do |resource|
        assert(resource.fetch.present?)
      end
    end
  end
end
