module Mulukhiya
  class MecabRemoteDictionaryTest < TestCase
    def setup
      @dic = RemoteDictionary.create(
        'url' => 'https://precure.ml/api/dic/v1/dic.json',
        'type' => 'mecab',
      )
    end

    def test_create
      assert_kind_of(MecabRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse

      assert_kind_of(Hash, result)
      assert_equal({pattern: /パルテノンモード/, regexp: 'パルテノンモード', words: ['パルテノンモード']}, result['パルテノンモード'])
    end
  end
end
