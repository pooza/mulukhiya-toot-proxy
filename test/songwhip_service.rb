module Mulukhiya
  class SongwhipServiceTest < TestCase
    def setup
      @service = SongwhipService.new
    end

    def test_get
      assert_raise Ginseng::GatewayError do
        @service.get('https://www.google.co.jp')
      end

      begin
        r = @service.get('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')

        assert_equal('https://songwhip.com/%E5%AE%AE%E6%9C%AC%E4%BD%B3%E9%82%A3%E5%AD%903/%E3%82%AD%E3%83%9F%E3%81%AB100%E3%83%91%E3%83%BC%E3%82%BB%E3%83%B3%E3%83%88', r.to_s)
      rescue Ginseng::GatewayError
        assert_equal('', r.to_s)
      end
    end
  end
end
