module Mulukhiya
  class GrowiClipperTest < TestCase
    def setup
      @clipper = Environment.test_account.growi
    end

    def test_create
      assert_kind_of(GrowiClipper, @clipper)
    end

    def test_clip
      r = @clipper.clip(
        body: "#{Time.now} #{__method__}",
        path: GrowiClipper.create_path(Environment.test_account.acct.username),
      )
      assert_kind_of(HTTParty::Response, r)
      assert_equal(200, r.code)
    end
  end
end
