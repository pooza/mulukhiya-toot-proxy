module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      @config = Config.instance
      @container = TagContainer.new
    end

    def test_default_tags
      @config['/tagging/default_tags'] = []
      assert_equal(TagContainer.default_tags, [])
      @config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end
  end
end
