module Mulukhiya
  class MultiFieldTaggingResourceTest < TestCase
    def setup
      @resource = TaggingResource.create(
        'url' => 'https://api.github.com/users/pooza/repos',
        'fields' => ['name'],
      )
    end

    def test_create
      assert_kind_of(MultiFieldTaggingResource, @resource)
    end

    def test_parse
      result = @resource.parse
      assert_kind_of(Hash, result)
      assert_equal(result['ginseng-core'], {pattern: /ginseng.? ?core/})
    end
  end
end
