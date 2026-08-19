require 'webmock/test_unit'

module Mulukhiya
  # リモート辞書が 200-with-HTML を掴んだときのふるまい (#4573)。
  #
  # ⚠ **HTTParty の parsed_response は Content-Type が JSON でなければ String を
  # そのまま返す。**GAS の /exec は失効すると HTTP 200 のまま text/html の
  # ログイン誘導ページを返すので、HTTP 層は成功・present? も通り、String#to_h /
  # String#each の NoMethodError として parse の奥で倒れていた。美食丼の related
  # 辞書 3 本が 10 分周期で全滅していたのに誰も気付けなかったのがこれ。
  class RemoteDictionarySchemaTest < TestCase
    URL = 'https://script.example.com/macros/s/dummy/exec'.freeze
    HTML = <<~HTML.freeze
      <!DOCTYPE html><html><head><title>ログイン</title></head>
      <body>アクセスするにはログインしてください。</body></html>
    HTML

    def setup
      WebMock.disable_net_connect!
    end

    def teardown
      super
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    # 型が外れたら GatewayError。parse の奥の NoMethodError ではなく、
    # 「何を期待して何が来たか」が message に出ること。
    def test_fetch_raises_for_html_body
      stub_html
      error = assert_raise(Ginseng::GatewayError) {dictionary('related').fetch}

      assert_include(error.message, 'String')
    end

    def test_fetch_raises_for_empty_body
      stub_request(:get, URL).to_return(
        status: 200,
        body: '',
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::GatewayError) {dictionary('related').fetch}
    end

    # ⚠ **3 サブクラスとも fail-open で {}。**以前は multi_field だけ外側の
    # rescue が無く、同じ入力で呼び出し元へ NoMethodError が抜けていた。
    def test_parse_is_fail_open_for_all_types
      stub_html
      types = ['related', 'mecab', 'multi_field']

      types.each {|type| assert_empty(dictionary(type).parse, "type=#{type}")}
    end

    # 期待する型は parse の前提と揃っていること。related は Hash、
    # mecab / multi_field は Array。
    def test_expected_class
      assert_equal(Hash, dictionary('related').expected_class)
      assert_equal(Array, dictionary('mecab').expected_class)
      assert_equal(Array, dictionary('multi_field').expected_class)
    end

    # JSON として読めても、サブクラスが前提にしている型でなければ弾く
    # (related の URL に一覧 JSON を向けてしまった等)。
    def test_fetch_raises_for_wrong_json_type
      stub_request(:get, URL).to_return(
        status: 200,
        body: [{'word' => 'キュアスタ'}].to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      assert_raise(Ginseng::GatewayError) {dictionary('related').fetch}
    end

    # 正常系まで塞いでいないこと。
    def test_fetch_accepts_expected_type
      stub_request(:get, URL).to_return(
        status: 200,
        body: {'キュアスタ' => ['プリキュア']}.to_json,
        headers: {'Content-Type' => 'application/json'},
      )
      dic = dictionary('related')

      assert_kind_of(Hash, dic.fetch)
      assert_equal(['キュアスタ', 'プリキュア'], dic.parse['キュアスタ'][:words])
    end

    private

    def stub_html
      stub_request(:get, URL).to_return(
        status: 200,
        body: HTML,
        headers: {'Content-Type' => 'text/html; charset=utf-8'},
      )
    end

    def dictionary(type)
      return RemoteDictionary.create('url' => URL, 'type' => type, 'fields' => ['word'])
    end
  end
end
