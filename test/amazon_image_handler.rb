module MulukhiyaTootProxy
  class AmazonImageHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance

      handler = Handler.create('amazon_image')
      handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])

      handler.exec({'status' => 'Amazon.co.jp | HUGっと!プリキュア オシマイダー Tシャツ ブラック XLサイズ | ホビー 通販 https://www.amazon.co.jp/dp/B07DB67ZR8'})
      assert_equal(handler.summary, 'AmazonImageHandler,1')

      handler.exec({'status' => 'https://www.amazon.co.jp/%E3%83%90%E3%83%B3%E3%83%80%E3%82%A4-BANDAI-%E3%82%B9%E3%82%BF%E3%83%BC%E2%98%86%E3%83%88%E3%82%A5%E3%82%A4%E3%83%B3%E3%82%AF%E3%83%AB%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E3%81%8A%E3%81%9B%E3%82%8F%E3%81%97%E3%81%A6%E3%83%95%E3%83%AF%E2%98%86%E3%83%88%E3%82%A5%E3%82%A4%E3%83%B3%E3%82%AF%E3%83%AB%E3%83%96%E3%83%83%E3%82%AF/dp/B07MHBMGMN/ref=sr_1_4?ie=UTF8&qid=1551303578&sr=8-4&keywords=%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2'})
      assert_equal(handler.summary, 'AmazonImageHandler,2')

      handler.exec({'status' => 'https://www.amazon.co.jp/gp/product/B07H2B56RT?pf_rd_p=7b903293-68b0-4a33-9b7c-65c76866a371&pf_rd_r=732H9VVYDF2TD3WYVBKK'})
      assert_equal(handler.summary, 'AmazonImageHandler,3')

      handler.exec({'status' => 'https://www.amazon.co.jp/gp/customer-reviews/R2W0VIBA0RBSLY/ref=cm_cr_dp_d_rvw_ttl?ie=UTF8&ASIN=B00TYVQBEU'})
      assert_equal(handler.summary, 'AmazonImageHandler,3')
    end
  end
end
