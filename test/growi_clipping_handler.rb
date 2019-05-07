module MulukhiyaTootProxy
  class GrowiClippingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('growi_clipping')
    end

    def test_exec
      @handler.exec({'status' => Time.now.to_s})
      assert_nil(@handler.result)
      sleep(1)

      @handler.exec({'status' => "#{Time.now} \#growi"})
      assert_equal(@handler.result[:entries].count, 1)
      sleep(1)
    end
  end
end
