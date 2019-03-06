module MulukhiyaTootProxy
  class TaggingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('tagging')

      assert_equal(handler.exec({'status' => 'hoge'})['status'], 'hoge')
      assert_equal(handler.result, 'TaggingHandler,0')

      assert_equal(handler.exec({'status' => '宮本佳那子'})['status'], "宮本佳那子\n#宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,1')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本佳那子。'})['status'], "キュアソードの中の人は宮本佳那子。\n#キュアソード #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,3')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本 佳那子。'})['status'], "キュアソードの中の人は宮本 佳那子。\n#キュアソード #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,5')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本　佳那子。'})['status'], "キュアソードの中の人は宮本　佳那子。\n#キュアソード #宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,7')

      assert_equal(handler.exec({'status' => '#キュアソード の中の人は宮本佳那子。'})['status'], "#キュアソード の中の人は宮本佳那子。\n#宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,8')

      assert_equal(handler.exec({'status' => 'Yes!プリキュア5'})['status'], "Yes!プリキュア5\n#Yes_プリキュア5")
      assert_equal(handler.result, 'TaggingHandler,9')

      assert_equal(handler.exec({'status' => 'Yes!プリキュア5 GoGo!'})['status'], "Yes!プリキュア5 GoGo!\n#Yes_プリキュア5GoGo")
      assert_equal(handler.result, 'TaggingHandler,10')

      assert_equal(handler.exec({'status' => "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド"})['status'], "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド\n#キュアフローラ #キュアマーメイド")
      assert_equal(handler.result, 'TaggingHandler,12')

      assert_equal(handler.exec({'status' => "#キュアビューティ"})['status'], "#キュアビューティ")
      assert_equal(handler.result, 'TaggingHandler,12')
    end
  end
end
