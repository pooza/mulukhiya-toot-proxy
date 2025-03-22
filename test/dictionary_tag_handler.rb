module Mulukhiya
  class DictionaryTagHandlerTest < TestCase
    def setup
      config['/handler/dictionary_tag/word/min'] = 3
      config['/handler/dictionary_tag/word/min_kanji'] = 2
      config['/agent/accts'] = ['@pooza']
      config['/handler/dictionary_tag/dics'] = [
        {'url' => 'https://precure.ml/api/dic/v1/precure.json', 'type' => 'related'},
        {'url' => 'https://precure.ml/api/dic/v1/singer.json', 'type' => 'related'},
        {'url' => 'https://precure.ml/api/dic/v1/series.json', 'type' => 'related'},
        {'url' => 'https://precure.ml/api/dic/v2/fairy.json'},
        {'url' => 'https://precure.ml/api/dic/v1/emoji.json', 'type' => 'related', 'strict' => true},
        {'url' => 'https://mstdn.delmulin.com/api/dic/v1/emoji.json', 'type' => 'related'},
      ]
      TaggingDictionary.new.refresh

      @handler = Handler.create(:dictionary_tag)
    end

    def teardown
      super
      TaggingDictionary.new.refresh
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => "つよく、やさしく、美しく。\n#キュアマーメイド")

      assert_equal(@handler.addition_tags, Set['キュアマーメイド', '海藤 みなみ', '浅野 真澄'])

      @handler.handle_pre_toot(status_field => ':maam_g:')

      assert_equal(@handler.addition_tags, Set['マァム'])
    end

    def test_handle_pre_toot_with_poll
      @handler.handle_pre_toot(
        status_field => 'アンケート',
        poll_field => {poll_options_field => ['項目1', '項目2', 'ふたりはプリキュア']},
      )

      assert_equal(@handler.addition_tags, Set['ふたりはプリキュア'])
    end
  end
end
