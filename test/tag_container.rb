module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
    end

    def test_default_tags
      assert_equal(DefaultTagHandler.tags, Set['美食丼', 'b-shock-don'])
    end

    def test_remote_default_tags
      assert_equal(TagContainer.remote_default_tags, Set['precure_fun', 'delmulin'])
    end
  end
end
