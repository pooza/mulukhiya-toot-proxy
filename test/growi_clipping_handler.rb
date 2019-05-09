module MulukhiyaTootProxy
  class GrowiClippingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('growi_clipping')
    end

    def test_hook_pre_toot
      @handler.clear
      @handler.hook_pre_toot({'status' => Time.now.to_s})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.hook_pre_toot({'status' => "#{Time.now} \#growi"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
