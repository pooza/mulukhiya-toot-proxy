module Mulukhiya
  class GrowiClipperTest < TestCase
    def setup
      @clipper = Environment.test_account.growi
    end

    def test_create
      assert_kind_of(GrowiClipper, @clipper)
    end

    def test_clip
      assert_equal(200, @clipper.clip("#{Time.now} #{__method__}").code)
    end
  end
end
