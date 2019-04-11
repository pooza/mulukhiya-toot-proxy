module MulukhiyaTootProxy
  class TagContainerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
    end

    def test_create_tags
      container = TagContainer.new
      container.concat(['カレー担々麺', 'コスモグミ'])
      assert_equal(container.create_tags, ['#カレー担々麺', '#コスモグミ'])

      container.push('剣崎 真琴')
      container.push('Makoto Kenzaki')
      assert_equal(container.create_tags, ['#カレー担々麺', '#コスモグミ', '#剣崎真琴', '#Makoto_Kenzaki'])
    end

    def test_default_tags
      @config['/tagging/default_tags'] = []
      assert_equal(TagContainer.default_tags, [])
      @config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end
  end
end
