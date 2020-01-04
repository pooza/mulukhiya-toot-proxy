module MulukhiyaTootProxy
  class MecabTaggingResourceTest < TestCase
    def setup
      @resource = TaggingResource.create(
        'url' => 'https://script.google.com/macros/s/AKfycbws9aCXxNQt3khdJ9bEt1ADeV7HzZV_Idg-DvN5t_X3nnca0nc/exec',
        'type' => 'mecab',
      )
    end

    def test_create
      assert_kind_of(MecabTaggingResource, @resource)
    end

    def test_parse
      result = @resource.parse
      assert_kind_of(Hash, result)
      assert_equal(result['パルテノンモード'], {pattern: /パルテノンモード/})
    end
  end
end
