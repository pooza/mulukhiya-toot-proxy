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
          'url' => 'https://script.google.com/macros/s/AKfycbyy5EQHvhKfm1Lg6Ae4W7knG4BCSkvepJyB6MrzQ8UIxmFfZMJj/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://script.google.com/macros/s/AKfycbxkcvrTTieJCeGotxlyENQ5vpS1RQnoLFzH3ti5UOHsuTFOfpE/exec',
          'type' => 'relative',
        },
      ]
      @config['/tagging/ignore_addresses'] = ['@pooza']
    end

    def test_handle_pre_toot_without_default_tags
      @config['/tagging/default_tags'] = []

      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'hoge'})['status'])
      assert_equal(tags.count, 0)

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => '宮本佳那子'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('宮本佳那子'))

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'キュアソードの中の人は宮本佳那子。'})['status'])
      assert(tags.member?('宮本佳那子'))
      assert(tags.member?('キュアソード'))
      assert(tags.member?('剣崎真琴'))
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'キュアソードの中の人は宮本 佳那子。'})['status'])
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'キュアソードの中の人は宮本　佳那子。'})['status'])
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => '#キュアソード の中の人は宮本佳那子。'})['status'])
      assert_equal(tags.count, 3)

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'Yes!プリキュア5 GoGo!'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('Yes_プリキュア5GoGo'))

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'Yes!プリキュア5 Yes!プリキュア5 GoGo!'})['status'])
      assert_equal(tags.count, 2)
      assert(tags.member?('Yes_プリキュア5'))
      assert(tags.member?('Yes_プリキュア5GoGo'))

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => "つよく、やさしく、美しく。\n#キュアフローラ_キュアマーメイド"})['status'])
      assert_equal(tags.count, 7)
      assert(tags.member?('キュアフローラ_キュアマーメイド'))
      assert(tags.member?('キュアフローラ'))
      assert(tags.member?('春野はるか'))
      assert(tags.member?('嶋村侑'))
      assert(tags.member?('キュアマーメイド'))
      assert(tags.member?('海藤みなみ'))
      assert(tags.member?('浅野真澄'))

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => '#キュアビューティ'})['status'])
      assert_equal(tags.count, 3)
      assert(tags.member?('キュアビューティ'))
      assert(tags.member?('青木れいか'))
      assert(tags.member?('西村ちなみ'))
    end

    def test_handle_pre_toot_with_direct
      @handler.clear
      r = @handler.handle_pre_toot({
        'status' => 'キュアソード',
        'visibility' => 'direct',
      })
      assert_equal(r['status'], 'キュアソード')
    end

    def test_handle_pre_toot_with_default_tag
      @config['/tagging/default_tags'] = ['美食丼']
      @config['/tagging/always_default_tags'] = true

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'hoge'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('美食丼'))

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => '宮本佳那子'})['status'])
      assert_equal(tags.count, 2)
      assert(tags.member?('美食丼'))
      assert(tags.member?('宮本佳那子'))

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => '#美食丼'})['status'])
      assert_equal(tags.count, 1)
      assert(tags.member?('美食丼'))

      @config['/tagging/always_default_tags'] = false

      @handler.clear
      tags = TagContainer.scan(@handler.handle_pre_toot({'status' => 'hoge', 'visibility' => 'unlisted'})['status'])
      assert_equal(tags.count, 0)

      @handler.clear
      r = @handler.handle_pre_toot({
        'status' => '@pooza@mstdn.precure.fun',
        'visibility' => 'private',
      })
      assert_equal(r['status'], '@pooza@mstdn.precure.fun')
    end

    def test_handle_pre_toot_with_poll
      @config['/tagging/default_tags'] = []

      @handler.clear
      body = {
        'status' => 'アンケート',
        'poll' => {'options' => ['項目1', '項目2', 'ふたりはプリキュア']},
      }
      assert_equal(@handler.handle_pre_toot(body)['status'], "アンケート\n#ふたりはプリキュア")
    end

    def test_end_with_tags?
      @config['/tagging/default_tags'] = []

      @handler.clear
      last = @handler.handle_pre_toot({'status' => '宮本佳那子'})['status'].each_line.to_a.last.chomp
      assert_equal(last, '#宮本佳那子')

      @handler.clear
      last = @handler.handle_pre_toot({'status' => "宮本佳那子\n#aaa #bbb"})['status'].each_line.to_a.last.chomp
      assert_equal(last, '#宮本佳那子 #aaa #bbb')
    end

    def test_ignore_addresses
      @config['/tagging/default_tags'] = []
      @handler.clear
      assert_equal(@handler.handle_pre_toot({'status' => '@pooza #キュアビューティ'})['status'], '@pooza #キュアビューティ')
    end
  end
end
