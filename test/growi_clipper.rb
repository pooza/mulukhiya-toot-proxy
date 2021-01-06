module Mulukhiya
  class GrowiClipperTest < TestCase
    def test_create
      assert_kind_of(GrowiClipper, account.growi)
    end

    def test_clip
      r = account.growi.clip(body: "#{Time.now} #{__method__}")
      assert_kind_of(HTTParty::Response, r)
      assert_equal(200, r.code)
    end
  end
end
