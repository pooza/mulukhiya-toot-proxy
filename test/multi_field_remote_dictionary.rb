module Mulukhiya
  class MultiFieldRemoteDictionaryTest < TestCase
    def setup
      @dic = RemoteDictionary.create(
        'url' => 'https://api.github.com/users/pooza/repos',
        'fields' => ['name'],
      )
    end

    def test_create
      assert_kind_of(MultiFieldRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse
      assert_kind_of(Hash, result)
      assert_equal({pattern: /ginseng.? ?core/, regexp: 'ginseng.? ?core', words: []}, result['ginseng-core'])
    end
  end
end
