module Mulukhiya
  class RelativeRemoteDictionaryTest < TestCase
    def setup
      @dic = RemoteDictionary.create(
        'url' => 'https://script.google.com/macros/s/AKfycbwn4nqKhBwH3aDYd7bJ698-GWRJqpktpAdH11ramlBK87ym3ME/exec',
        'type' => 'relative',
      )
    end

    def test_create
      assert_kind_of(RelativeRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse
      assert_kind_of(Hash, result)
      assert_equal(result['キュアブロッサム'], {pattern: /キ[ユュ][アァ]ブロッサム/, words: ['花咲 つぼみ', '水樹 奈々']})
    end
  end
end
