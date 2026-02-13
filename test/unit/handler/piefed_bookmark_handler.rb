module Mulukhiya
  class PiefedBookmarkHandlerTest < TestCase
    def setup
      @handler = Handler.create(:piefed_bookmark)
    end

    def test_worker_class
      assert_equal(PiefedClippingWorker, @handler.worker_class)
    end
  end
end
