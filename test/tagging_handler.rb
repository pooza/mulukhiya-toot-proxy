module Mulukhiya
  class TaggingHandlerTest < TestCase
    def setup
      config['/tagging/word/minimum_length'] = 3
      config['/agent/accts'] = ['@pooza']
      config['/tagging/dictionaries'] = [
        {'url' => 'https://precure.ml/api/dic/v1/precure.json', 'type' => 'relative'},
        {'url' => 'https://precure.ml/api/dic/v1/singer.json', 'type' => 'relative'},
        {'url' => 'https://precure.ml/api/dic/v1/series.json', 'type' => 'relative'},
        {'url' => 'https://precure.ml/api/dic/v2/fairy.json'},
      ]
      TaggingDictionary.new.refresh

      @handler = Handler.create('tagging')
      @parser = Environment.parser_class.new
    end

    def teardown
      super
      TaggingDictionary.new.refresh
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @parser.text = @handler.handle_pre_toot(status_field => '宮本佳那子')[status_field]
      assert(@parser.all_tags.member?('#宮本佳那子'))

      @handler.clear
      @parser.text = @handler.handle_pre_toot(status_field => 'キュアソードの中の人は宮本佳那子。')[status_field]
      assert(@parser.all_tags.member?('#宮本佳那子'))
      assert(@parser.all_tags.member?('#キュアソード'))
      assert(@parser.all_tags.member?('#剣崎真琴'))

      @handler.clear
      @parser.text = @handler.handle_pre_toot(status_field => 'Yes!プリキュア5 GoGo!')[status_field]
      assert(@parser.all_tags.member?('#Yes_プリキュア5GoGo'))

      @handler.clear
      @parser.text = @handler.handle_pre_toot(status_field => 'Yes!プリキュア5 Yes!プリキュア5 GoGo!')[status_field]
      assert(@parser.all_tags.member?('#Yes_プリキュア5'))
      assert(@parser.all_tags.member?('#Yes_プリキュア5GoGo'))

      @handler.clear
      @parser.text = @handler.handle_pre_toot(status_field => "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド")[status_field]
      assert(@parser.all_tags.member?('#キュアフローラ_キュアマーメイド'))
      assert(@parser.all_tags.member?('#キュアフローラ'))
      assert(@parser.all_tags.member?('#春野はるか'))
      assert(@parser.all_tags.member?('#嶋村侑'))
      assert(@parser.all_tags.member?('#キュアマーメイド'))
      assert(@parser.all_tags.member?('#海藤みなみ'))
      assert(@parser.all_tags.member?('#浅野真澄'))

      @handler.clear
      @parser.text = @handler.handle_pre_toot(status_field => '#キュアビューティ')[status_field]
      assert(@parser.all_tags.member?('#キュアビューティ'))
      assert(@parser.all_tags.member?('#青木れいか'))
      assert(@parser.all_tags.member?('#西村ちなみ'))
    end

    def test_handle_pre_toot_with_direct
      return unless handler?

      @handler.clear
      r = @handler.handle_pre_toot({status_field => 'キュアソード', 'visibility' => 'direct'})
      assert_equal(r[status_field], 'キュアソード')
    end

    def test_handle_pre_toot_with_poll
      return unless handler?

      @handler.clear
      body = {
        status_field => 'アンケート',
        'poll' => {
          controller_class.poll_options_field => ['項目1', '項目2', 'ふたりはプリキュア'],
        },
      }
      assert(@handler.handle_pre_toot(body)[status_field].start_with?("アンケート\n#ふたりはプリキュア"))
    end

    def test_handle_pre_toot_with_twittodon
      return unless handler?
      config['/tagging/default_tags'] = []

      @handler.clear
      body = {status_field => "みんな〜！「スター☆トゥインクルプリキュア  おほしSUMMERバケーション」が今日もオープンしているよ❣️会場内では、スタンプラリーを開催中！！😍🌈今年のスタンプラリーシートは…なんと！トゥインクルブック型！！🌟フワも登場してとーっても可愛いデザインだよ💖スタンプを全て集めると、「夜空でピカッとステッカー」も貰えちゃう！😍みんなは全部見つけられるかな！？会場内で、ぜひチェックしてね！💫 #スタートゥインクルプリキュア#おほしSUMMERバケーション#スタプリ#池袋プリキュア #フワ#トゥインクルブック#スタンプラリー\n\nvia. https://www.instagram.com/precure_event/p/"}
      lines = @handler.handle_pre_toot(body)[status_field].split("\n")
      assert_equal(lines.last, 'via. https://www.instagram.com/precure_event/p/')

      @handler.clear
      body = {status_field => "【新商品】「プリキュアランド第2弾 SPLASH☆WATER」より『アクリルスタンド』『シーズンパスポート』『缶バッジ』が8/25(日)発売だよ！ あっつ～い夏に楽しく元気に水遊びをするみんなを見てたらこちらも涼しくなっちゃう？ それともヒートアップしちゃう？ #プリキュア #プリティストア\n\n(via. Twitter https://twitter.com/pps_as/status/1161472629217218560)"}
      lines = @handler.handle_pre_toot(body)[status_field].split("\n")
      assert_equal(lines.last, '(via. Twitter https://twitter.com/pps_as/status/1161472629217218560)')
    end

    def test_ignore_accts
      return unless handler?

      @handler.clear
      assert(@handler.handle_pre_toot({status_field => '@pooza #キュアビューティ'})[status_field].start_with?('@pooza #キュアビューティ'))
    end
  end
end
