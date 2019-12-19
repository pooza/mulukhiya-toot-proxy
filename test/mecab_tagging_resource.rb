module MulukhiyaTootProxy
  class MecabTaggingResourceTest < TestCase
    def setup
      @resource = TaggingResource.create(
        'url' => 'https://script.google.com/macros/s/AKfycbws9aCXxNQt3khdJ9bEt1ADeV7HzZV_Idg-DvN5t_X3nnca0nc/exec',
        'type' => 'mecab',
      )
    end

    def test_new
      assert(@resource.is_a?(MecabTaggingResource))
    end

    def test_parse
      result = @resource.parse
      assert(result.is_a?(Hash))
      assert_equal(result['パルテノンモード'], {pattern: /パルテノンモード/})
    end
  end
end
