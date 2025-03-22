module Mulukhiya
  class RelatedRemoteDictionaryTest < TestCase
    def setup
      @dic = RemoteDictionary.create(
        'url' => 'https://script.google.com/macros/s/AKfycbwn4nqKhBwH3aDYd7bJ698-GWRJqpktpAdH11ramlBK87ym3ME/exec',
        'type' => 'related',
      )
    end

    def test_create
      assert_kind_of(RelatedRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse

      assert_kind_of(Hash, result)
      assert_equal({pattern: /キ[ユュ][アァ]ブロッサム/, regexp: 'キ[ユュ][アァ]ブロッサム', words: ['キュアブロッサム', '花咲 つぼみ', '水樹 奈々']}, result['キュアブロッサム'])
    end
  end
end
