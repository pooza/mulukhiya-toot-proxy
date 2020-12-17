module Mulukhiya
  class MecabRemoteDictionaryTest < TestCase
    def setup
      @dic = RemoteDictionary.create(
        'url' => 'https://script.google.com/macros/s/AKfycbws9aCXxNQt3khdJ9bEt1ADeV7HzZV_Idg-DvN5t_X3nnca0nc/exec',
        'type' => 'mecab',
      )
    end

    def test_create
      assert_kind_of(MecabRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse
      assert_kind_of(Hash, result)
      assert_equal(result['パルテノンモード'], {pattern: /パルテノンモード/, regexp: 'パルテノンモード', words: []})
    end
  end
end
