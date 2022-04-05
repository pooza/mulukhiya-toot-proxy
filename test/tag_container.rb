module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      config['/handler/default_tag/tags'] = ['美食丼', 'b-shock-don']
      @tags = TagContainer.new
    end

    def test_delete
      @tags.add('tver')
      assert_equal(Set['tver'], @tags)

      @tags.delete('TVer')
      assert_equal(Set[], @tags)
    end

    def test_default_tags
      assert_equal(TagContainer.default_tags, Set['美食丼', 'b-shock-don'])
    end

    def test_remote_default_tags
      assert_equal(TagContainer.remote_default_tags, Set['precure_fun', 'delmulin'])
    end
  end
end
