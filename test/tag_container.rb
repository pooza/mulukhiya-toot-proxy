module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
      config['/tagging/remote_default_tags'] = ['gochisou_photo']
    end

    def test_default_tags
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end

    def test_remote_default_tags
      assert_equal(TagContainer.remote_default_tags, ['#gochisou_photo'])
    end
  end
end
