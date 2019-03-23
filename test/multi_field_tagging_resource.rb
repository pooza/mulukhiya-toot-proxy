module MulukhiyaTootProxy
  class MultiFieldTaggingResourceTest < Test::Unit::TestCase
    def setup
      @resource = TaggingResource.create({
        'url' => 'https://rubicure.herokuapp.com/series.json',
        'fields' => ['title'],
      })
    end

    def test_new
      assert(@resource.is_a?(MultiFieldTaggingResource))
    end

    def test_parse
      result = @resource.parse
      assert(result.is_a?(Hash))
      assert_equal(result['スター☆トゥインクルプリキュア'], {pattern: /スター.?トゥインクルプリキュア/})
    end
  end
end
