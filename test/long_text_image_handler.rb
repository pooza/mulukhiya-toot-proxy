require 'timecop'

module Mulukhiya
  class LontTextImageHandlerTest < TestCase
    def setup
      @handler = Handler.create('long_text_image')
    end

    def test_disable?
      Timecop.travel(Time.parse('2021/03/31'))
      assert(@handler.disable?)

      Timecop.travel(Time.parse('2021/04/01'))
      assert_false(@handler.disable?)

      Timecop.travel(Time.parse('2021/04/02'))
      assert(@handler.disable?)

      Timecop.return
    end

    def test_executable?
      assert_false(@handler.executable?(status_field => 'A' * 140))
      assert(@handler.executable?(status_field => 'A' * 141))
    end

    def test_handle_pre_webhook; end
  end
end
