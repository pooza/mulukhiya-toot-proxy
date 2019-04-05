module MulukhiyaTootProxy
  class TagContainerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
    end

    def test_create_tags
      container = TagContainer.new
      container.concat(['カレー担々麺', 'コスモグミ'])
      assert_equal(container.create_tags, ['#カレー担々麺', '#コスモグミ'])
    end

    def test_default_tags
      @config['/tagging/default_tags'] = []
      assert_equal(TagContainer.default_tags, [])
      @config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end
  end
end
