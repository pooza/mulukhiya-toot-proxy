module Mulukhiya
  class TagContainerTest < TestCase
    def disable?
      return true if Environment.ci?
      return super
    end

    def setup
      config['/handler/default_tag/tags'] = ['美食丼', 'b-shock-don']
      config['/tagging/normalize/rules'] = [
        {'source' => 'ふたりはプリキュア_Max_Heart', 'normalized' => 'ふたりはプリキュアMax_Heart'},
        {'source' => 'ドラゴンクエスト_ダイの大冒険_2020年版', 'normalized' => 'ドラゴンクエストダイの大冒険'},
      ]
      @tags = TagContainer.new
    end

    def test_normalize
      assert_equal('ドラゴンクエストダイの大冒険', @tags.normalize('ドラゴンクエスト_ダイの大冒険_2020年版'))
    end

    def test_delete
      @tags.add('tver')
      assert_equal(Set['tver'], @tags)

      @tags.delete('TVer')
      assert_equal(Set[], @tags)
    end

    def test_scan
      assert_kind_of(TagContainer, TagContainer.scan('インドの山奥で修業して'))
    end

    def test_default_tags
      assert_equal(TagContainer.default_tags, Set['美食丼', 'b-shock-don'])
    end

    def test_remote_default_tags
      assert_equal(TagContainer.remote_default_tags, Set['precure_fun', 'delmulin'])
    end
  end
end
