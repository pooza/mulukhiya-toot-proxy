module MulukhiyaTootProxy
  class TaggingHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @config['/tagging/dictionaries'] = [
        {
          'url' => 'https://script.google.com/macros/s/AKfycbwn4nqKhBwH3aDYd7bJ698-GWRJqpktpAdH11ramlBK87ym3ME/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://script.google.com/macros/s/AKfycbzAUsRUuFLO72EgKta020v9OMtxvUtqUcPZNJ3_IMlOo8dRO7tW/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://rubicure.herokuapp.com/series.json',
          'fields' => ['title'],
        },
      ]
    end

    def test_exec_without_default_tags
      @config['/tagging/default_tags'] = []
      handler = Handler.create('tagging')

      assert_equal(handler.exec({'status' => 'hoge'})['status'], 'hoge')
      assert_equal(handler.result, 'TaggingHandler,0')

      assert_equal(handler.exec({'status' => '宮本佳那子'})['status'], "宮本佳那子\n#宮本佳那子 #キュアソード #剣崎真琴")
      assert_equal(handler.result, 'TaggingHandler,3')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本佳那子。'})['status'], "キュアソードの中の人は宮本佳那子。\n#キュアソード #剣崎真琴 #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,6')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本 佳那子。'})['status'], "キュアソードの中の人は宮本 佳那子。\n#キュアソード #剣崎真琴 #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,9')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本　佳那子。'})['status'], "キュアソードの中の人は宮本　佳那子。\n#キュアソード #剣崎真琴 #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,12')

      assert_equal(handler.exec({'status' => '#キュアソード の中の人は宮本佳那子。'})['status'], "#キュアソード の中の人は宮本佳那子。\n#剣崎真琴 #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,14')

      assert_equal(handler.exec({'status' => 'Yes!プリキュア5'})['status'], "Yes!プリキュア5\n#Yes_プリキュア5")
      assert_equal(handler.result, 'TaggingHandler,15')

      assert_equal(handler.exec({'status' => 'Yes!プリキュア5 GoGo!'})['status'], "Yes!プリキュア5 GoGo!\n#Yes_プリキュア5GoGo")
      assert_equal(handler.result, 'TaggingHandler,16')

      assert_equal(handler.exec({'status' => "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド"})['status'], "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド\n#キュアフローラ #春野はるか #嶋村侑 #キュアマーメイド #海藤みなみ #浅野真澄")
      assert_equal(handler.result, 'TaggingHandler,22')

      assert_equal(handler.exec({'status' => '#キュアビューティ'})['status'], "#キュアビューティ\n#青木れいか #西村ちなみ")
      assert_equal(handler.result, 'TaggingHandler,24')
    end

    def test_exec_with_default_tag
      @config['/tagging/default_tags'] = ['美食丼']
      handler = Handler.create('tagging')

      assert_equal(handler.exec({'status' => 'hoge'})['status'], "hoge\n#美食丼")
      assert_equal(handler.result, 'TaggingHandler,1')

      assert_equal(handler.exec({'status' => '宮本佳那子'})['status'], "宮本佳那子\n#宮本佳那子 #キュアソード #剣崎真琴 #美食丼")
      assert_equal(handler.result, 'TaggingHandler,5')

      assert_equal(handler.exec({'status' => '#美食丼'})['status'], '#美食丼')
      assert_equal(handler.result, 'TaggingHandler,5')
    end
  end
end
