module MulukhiyaTootProxy
  class TaggingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('tagging')

      assert_equal(handler.exec({'status' => 'hoge'})['status'], 'hoge')
      assert_equal(handler.result, 'TaggingHandler,0')

      assert_equal(handler.exec({'status' => '宮本佳那子'})['status'], "宮本佳那子\n#宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,1')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本佳那子。'})['status'], "キュアソードの中の人は宮本佳那子。\n#宮本佳那子 #キュアソード")
      assert_equal(handler.result, 'TaggingHandler,3')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本 佳那子。'})['status'], "キュアソードの中の人は宮本 佳那子。\n#宮本佳那子 #キュアソード")
      assert_equal(handler.result, 'TaggingHandler,5')

      assert_equal(handler.exec({'status' => 'キュアソードの中の人は宮本　佳那子。'})['status'], "キュアソードの中の人は宮本　佳那子。\n#宮本佳那子 #キュアソード")
      assert_equal(handler.result, 'TaggingHandler,7')

      assert_equal(handler.exec({'status' => '#キュアソード の中の人は宮本佳那子。'})['status'], "#キュアソード の中の人は宮本佳那子。\n#宮本佳那子")
      assert_equal(handler.result, 'TaggingHandler,8')
    end
  end
end
