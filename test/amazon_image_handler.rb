module MulukhiyaTootProxy
  class AmazonImageHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance
      return unless config['local']['amazon']

      handler = Handler.create('amazon_image')
      handler.mastodon = Mastodon.new(
        config['local']['instance_url'],
        config['local']['test']['token'],
      )

      handler.exec({'status' => 'Amazon.co.jp | HUGっと!プリキュア オシマイダー Tシャツ ブラック XLサイズ | ホビー 通販 https://www.amazon.co.jp/dp/B07DB67ZR8'})
      assert_equal(handler.result, 'AmazonImageHandler,1')

      handler.exec({'status' => 'https://www.amazon.co.jp/gp/customer-reviews/R2W0VIBA0RBSLY/ref=cm_cr_dp_d_rvw_ttl?ie=UTF8&ASIN=B00TYVQBEU'})
      assert_equal(handler.result, 'AmazonImageHandler,1')
    end
  end
end
