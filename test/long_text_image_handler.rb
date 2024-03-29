module Mulukhiya
  class LongTextImageHandlerTest < TestCase
    def setup
      @handler = Handler.create(:long_text_image)
    end

    def test_disable?
      return false unless Environment.production?

      Timecop.travel(Time.parse('2021/04/01'))

      Timecop.travel(Time.parse('2021/03/31'))

      assert_predicate(@handler, :disable?)

      Timecop.travel(Time.parse('2021/04/01'))

      assert_false(@handler.disable?)

      Timecop.travel(Time.parse('2021/04/02'))

      assert_predicate(@handler, :disable?)
    end

    def test_executable?
      assert_false(@handler.executable?(status_field => 'A' * 140))
      assert(@handler.executable?(status_field => 'A' * 141))
    end

    def test_handle_pre_toot
      Timecop.travel(Time.parse('2021/04/01'))

      @handler.handle_pre_toot(status_field => 'あ' * 500)

      assert_equal({message: '今日は4月1日です。'}, @handler.debug_info[:result].first)
    end
  end
end
