module MulukhiyaTootProxy
  class GrowiClippingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('growi_clipping')
    end

    def test_handle_pre_toot
      return if ENV['CI'].present?

      @handler.clear
      @handler.handle_pre_toot({'status' => Time.now.to_s})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.handle_pre_toot({'status' => "#{Time.now} \#growi"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
