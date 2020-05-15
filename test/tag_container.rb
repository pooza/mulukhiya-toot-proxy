module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      @config = Config.instance
      @config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
      @container = TagContainer.new
    end

    def test_default_tags
      assert_equal(@container.default_tags, ['#美食丼', '#b_shock_don'])
    end
  end
end
