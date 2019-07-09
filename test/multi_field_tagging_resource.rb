module MulukhiyaTootProxy
  class MultiFieldTaggingResourceTest < Test::Unit::TestCase
    def setup
      @resource = TaggingResource.create(
        'url' => 'https://api.github.com/users/pooza/repos',
        'fields' => ['name'],
      )
    end

    def test_new
      assert(@resource.is_a?(MultiFieldTaggingResource))
    end

    def test_parse
      result = @resource.parse
      assert(result.is_a?(Hash))
      assert_equal(result['mulukhiya-toot-proxy'], {pattern: /mulukhiya.? ?toot.? ?proxy/})
    end
  end
end
