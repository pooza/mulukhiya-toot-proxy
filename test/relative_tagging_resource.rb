module MulukhiyaTootProxy
  class RelativeTaggingResourceTest < TestCase
    def setup
      @resource = TaggingResource.create(
        'url' => 'https://script.google.com/macros/s/AKfycbwn4nqKhBwH3aDYd7bJ698-GWRJqpktpAdH11ramlBK87ym3ME/exec',
        'type' => 'relative',
      )
    end

    def test_new
      assert(@resource.is_a?(RelativeTaggingResource))
    end

    def test_parse
      result = @resource.parse
      assert(result.is_a?(Hash))
      assert_equal(result['キュアブロッサム'], {pattern: /キ[ユュ][アァ]ブロッサム/, words: ['花咲 つぼみ', '水樹 奈々']})
    end
  end
end
