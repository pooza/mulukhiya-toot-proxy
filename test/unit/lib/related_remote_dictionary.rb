require 'webmock/test_unit'

module Mulukhiya
  # 実在の外部エンドポイント（実体は Google Apps Script）を叩くと、CI が
  # サードパーティのスロットリングで断続的に落ちる (#4497)。fixture で固定する。
  class RelatedRemoteDictionaryTest < TestCase
    URL = 'https://precure.ml/api/dic/v1/precure.json'.freeze

    def setup
      WebMock.disable_net_connect!
      stub_request(:get, URL).to_return(
        status: 200,
        body: fixture('precure_dic_related.json'),
        headers: {'Content-Type' => 'application/json'},
      )
      @dic = RemoteDictionary.create('url' => URL, 'type' => 'related')
    end

    def teardown
      super
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    def test_create
      assert_kind_of(RelatedRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse

      assert_kind_of(Hash, result)
      assert_equal(
        {
          pattern: /キ[ユュ][アァ]ブロッサム/,
          regexp: 'キ[ユュ][アァ]ブロッサム',
          words: ['キュアブロッサム', '花咲 つぼみ', '水樹 奈々'],
        },
        result['キュアブロッサム'],
      )
    end
  end
end
