module Mulukhiya
  class AmazonImageHandlerTest < TestCase
    def setup
      @handler = Handler.create('amazon_image')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.amazon.co.jp/gp/customer-reviews/R2W0VIBA0RBSLY/ref=cm_cr_dp_d_rvw_ttl?ie=UTF8&ASIN=B00TYVQBEU')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.amazon.co.jp/dp/B08JH42SHR')
      assert(@handler.debug_info[:result].present?)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.amazon.co.jp/dp/B08BDYBCLQ')
      assert(@handler.debug_info[:result].present?)
    end
  end
end
