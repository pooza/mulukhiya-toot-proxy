module MulukhiyaTootProxy
  class TaggingHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('tagging')
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
      @config['/tagging/ignore_addresses'] = ['@pooza']
    end

    def test_exec_without_default_tags
      @config['/tagging/default_tags'] = []

      tags = TagContainer.scan(@handler.exec({'status' => 'hoge'})['status'])
      assert_equal(tags.count, 0)

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => '宮本佳那子'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('宮本佳那子'))

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'キュアソードの中の人は宮本佳那子。'})['status'])
      assert(tags.member?('宮本佳那子'))
      assert(tags.member?('キュアソード'))
      assert(tags.member?('剣崎真琴'))
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'キュアソードの中の人は宮本 佳那子。'})['status'])
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'キュアソードの中の人は宮本　佳那子。'})['status'])
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => '#キュアソード の中の人は宮本佳那子。'})['status'])
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'Yes!プリキュア5 GoGo!'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('Yes_プリキュア5GoGo'))

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'Yes!プリキュア5 Yes!プリキュア5 GoGo!'})['status'])
      assert_equal(tags.count, 2)
      assert(tags.member?('Yes_プリキュア5'))
      assert(tags.member?('Yes_プリキュア5GoGo'))

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド"})['status'])
      assert_equal(tags.count, 7)
      assert(tags.member?('キュアフローラ_キュアマーメイド'))
      assert(tags.member?('キュアフローラ'))
      assert(tags.member?('春野はるか'))
      assert(tags.member?('嶋村侑'))
      assert(tags.member?('キュアマーメイド'))
      assert(tags.member?('海藤みなみ'))
      assert(tags.member?('浅野真澄'))

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => '#キュアビューティ'})['status'])
      assert_equal(tags.count, 3)
      assert(tags.member?('キュアビューティ'))
      assert(tags.member?('青木れいか'))
      assert(tags.member?('西村ちなみ'))
    end

    def test_exec_with_default_tag
      @config['/tagging/default_tags'] = ['美食丼']
      @config['/tagging/always_default_tags'] = true

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'hoge'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('美食丼'))

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => '宮本佳那子'})['status'])
      assert_equal(tags.count, 2)
      assert(tags.member?('美食丼'))
      assert(tags.member?('宮本佳那子'))

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => '#美食丼'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('美食丼'))

      @config['/tagging/always_default_tags'] = false

      @handler.clear
      tags = TagContainer.scan(@handler.exec({'status' => 'hoge', 'visibility' => 'unlisted'})['status'])
      assert_equal(tags.count, 0)
    end

    def test_end_with_tags?
      @config['/tagging/default_tags'] = []
      @handler.clear

      last = @handler.exec({'status' => '宮本佳那子'})['status'].each_line.to_a.last.chomp
      assert_equal(last, '#宮本佳那子')

      last = @handler.exec({'status' => "宮本佳那子\n#aaa #bbb"})['status'].each_line.to_a.last.chomp
      assert_equal(last, '#宮本佳那子 #aaa #bbb')
    end

    def test_ignore_addresses
      @config['/tagging/default_tags'] = []
      @handler.clear
      assert_equal(@handler.exec({'status' => '@pooza #キュアビューティ'})['status'], '@pooza #キュアビューティ')
    end
  end
end
