require 'mulukhiya/handler/amazon_image'
require 'mulukhiya/config'

module MulukhiyaTootProxy
  class AmazonImageHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = AmazonImageHandler.new
      config = Config.instance
      return unless config['local']['amazon']

      handler.exec(
        {'status' => 'Amazon.co.jp | HUGっと!プリキュア オシマイダー Tシャツ ブラック XLサイズ | ホビー 通販 https://www.amazon.co.jp/dp/B07DB67ZR8'},
        {'HTTP_AUTHORIZATION' => "Bearer #{config['local']['test']['token']}"},
      )
      assert_equal(handler.result, 'AmazonImageHandler,1')
    end
  end
end
