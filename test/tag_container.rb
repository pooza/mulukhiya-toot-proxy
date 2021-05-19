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

    def test_create_tags
      container = TagContainer.new

      container.clear
      container.push('武田 信玄')
      assert_equal(container.create_tags, ['#武田信玄'])

      container.clear
      container.push('Yes!プリキュア5 GoGo!')
      assert_equal(container.create_tags, ['#Yes_プリキュア5GoGo'])

      container.clear
      container.push('よにんでSUPER TEUCHI STATION ONLINE')
      assert_equal(container.create_tags, ['#よにんでSUPER_TEUCHI_STATION_ONLINE'])
    end
  end
end
