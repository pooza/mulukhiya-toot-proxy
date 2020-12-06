module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      @config = Config.instance
      @config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
    end

    def test_default_tags
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end

    def test_all_futured_tag_bases
      TagContainer.futured_tag_bases do |tag|
        assert_kind_of(String, tag)
      end
    end
  end
end
