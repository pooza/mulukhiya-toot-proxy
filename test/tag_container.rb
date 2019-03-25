module MulukhiyaTootProxy
  class TagContainerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
    end

    def test_push
      container = TagContainer.new
      container.push('単語1')
      container.push('単語2')
      assert_equal(container, ['単語1', '単語2'])
      container.push('単語223')
      assert_equal(container, ['単語1', '単語223'])
    end

    def test_concat
      container = TagContainer.new
      container.push('単語1')
      container.concat(['単語12', '単語4', '単語5'])
      assert_equal(container, ['単語12', '単語4', '単語5'])
    end

    def test_create_tags
      @config['/tagging/default_tags'] = ['美食丼']
      container = TagContainer.new
      container.concat(['カレー担々麺', 'コスモグミ'])
      assert_equal(container.create_tags, ['#カレー担々麺', '#コスモグミ', '#美食丼'])
    end

    def test_default_tags
      @config['/tagging/default_tags'] = []
      assert_equal(TagContainer.default_tags, [])
      @config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end
  end
end
