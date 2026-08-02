require 'webmock/test_unit'

module Mulukhiya
  # 実在の外部エンドポイント（実体は Google Apps Script）を叩くと、CI が
  # サードパーティのスロットリングで断続的に落ちる (#4497)。fixture で固定する。
  class MecabRemoteDictionaryTest < TestCase
    URL = 'https://precure.ml/api/dic/v1/dic.json'.freeze

    def setup
      WebMock.disable_net_connect!
      stub_request(:get, URL).to_return(
        status: 200,
        body: fixture('precure_dic_mecab.json'),
        headers: {'Content-Type' => 'application/json'},
      )
      @dic = RemoteDictionary.create('url' => URL, 'type' => 'mecab')
    end

    def teardown
      super
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    def test_create
      assert_kind_of(MecabRemoteDictionary, @dic)
    end

    def test_parse
      result = @dic.parse

      assert_kind_of(Hash, result)
      assert_equal(
        {pattern: /パルテノンモード/, regexp: 'パルテノンモード', words: ['パルテノンモード']},
        result['パルテノンモード'],
      )
    end

    # 固有名詞のうち人名（姓・名）と、そもそも固有名詞でない語は落とす。
    def test_parse_rejects_personal_names_and_common_nouns
      result = @dic.parse

      assert_not_include(result, '愛崎') # 固有名詞・人名・姓
      assert_not_include(result, 'あおい') # 固有名詞・人名・名
      assert_not_include(result, 'アイスドラゴン') # 名詞・一般
    end
  end
end
