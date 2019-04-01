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

      tags = TagContainer.scan(handler.exec({'status' => 'hoge'})['status'])
      assert_equal(tags.count, 0)
      assert_equal(handler.result, 'TaggingHandler,0')

      tags = TagContainer.scan(handler.exec({'status' => '宮本佳那子'})['status'])
      assert_equal(tags.count, 3)
      assert(tags.member?('宮本佳那子'))
      assert(tags.member?('剣崎真琴'))
      assert(tags.member?('キュアソード'))
      assert_equal(handler.result, 'TaggingHandler,3')

      tags = TagContainer.scan(handler.exec({'status' => 'キュアソードの中の人は宮本佳那子。'})['status'])
      assert_equal(tags.count, 3)
      assert_equal(handler.result, 'TaggingHandler,6')

      tags = TagContainer.scan(handler.exec({'status' => 'キュアソードの中の人は宮本 佳那子。'})['status'])
      assert_equal(tags.count, 3)
      assert_equal(handler.result, 'TaggingHandler,9')

      tags = TagContainer.scan(handler.exec({'status' => 'キュアソードの中の人は宮本　佳那子。'})['status'])
      assert_equal(tags.count, 3)
      assert_equal(handler.result, 'TaggingHandler,12')

      tags = TagContainer.scan(handler.exec({'status' => '#キュアソード の中の人は宮本佳那子。'})['status'])
      assert_equal(tags.count, 3)
      assert_equal(handler.result, 'TaggingHandler,14')

      tags = TagContainer.scan(handler.exec({'status' => 'Yes!プリキュア5 Yes!プリキュア5 GoGo!'})['status'])
      assert_equal(tags.count, 2)
      assert(tags.member?('Yes_プリキュア5'))
      assert(tags.member?('Yes_プリキュア5GoGo'))
      assert_equal(handler.result, 'TaggingHandler,16')

      tags = TagContainer.scan(handler.exec({'status' => 'Yes!プリキュア5 GoGo!'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('Yes_プリキュア5GoGo'))
      assert_equal(handler.result, 'TaggingHandler,17')

      tags = TagContainer.scan(handler.exec({'status' => "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド"})['status'])
      assert_equal(tags.count, 7)
      assert(tags.member?('キュアフローラ_キュアマーメイド'))
      assert(tags.member?('キュアフローラ'))
      assert(tags.member?('春野はるか'))
      assert(tags.member?('嶋村侑'))
      assert(tags.member?('キュアマーメイド'))
      assert(tags.member?('海藤みなみ'))
      assert(tags.member?('浅野真澄'))
      assert_equal(handler.result, 'TaggingHandler,23')

      tags = TagContainer.scan(handler.exec({'status' => '#キュアビューティ'})['status'])
      assert_equal(tags.count, 3)
      assert(tags.member?('キュアビューティ'))
      assert(tags.member?('青木れいか'))
      assert(tags.member?('西村ちなみ'))
      assert_equal(handler.result, 'TaggingHandler,25')
    end

    def test_exec_with_default_tag
      @config['/tagging/default_tags'] = ['美食丼']
      handler = Handler.create('tagging')

      tags = TagContainer.scan(handler.exec({'status' => 'hoge'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('美食丼'))
      assert_equal(handler.result, 'TaggingHandler,1')

      tags = TagContainer.scan(handler.exec({'status' => '宮本佳那子'})['status'])
      assert_equal(tags.count, 4)
      assert(tags.member?('美食丼'))
      assert(tags.member?('宮本佳那子'))
      assert(tags.member?('剣崎真琴'))
      assert(tags.member?('キュアソード'))
      assert_equal(handler.result, 'TaggingHandler,5')

      tags = TagContainer.scan(handler.exec({'status' => '#美食丼'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('美食丼'))
      assert_equal(handler.result, 'TaggingHandler,5')
    end
  end
end
