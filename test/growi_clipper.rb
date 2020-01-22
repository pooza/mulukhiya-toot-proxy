module Mulukhiya
  class GrowiClipperTest < TestCase
    def setup
      @clipper = Environment.test_account.growi
    end

    def test_create
      assert_kind_of(GrowiClipper, @clipper)
    end

    def test_clip
      assert_kind_of(CPApiReturn, @clipper.clip("#{Time.now} #{__method__}"))
    end
  end
end
