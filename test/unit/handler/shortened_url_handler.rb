module Mulukhiya
  class ShortenedURLHandlerTest < TestCase
    def setup
      @handler = Handler.create(:shortened_url)
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => 'https://t.co/6Um3INeyU9')

      assert_equal({result: [{source_url: 'https://t.co/6Um3INeyU9', rewrited_url: 'https://www.youtube.com/watch?v=Ipsa3rgH1Cs&feature=youtu.be'}], errors: []}, @handler.debug_info)
    end
  end
end
