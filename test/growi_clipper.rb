module Mulukhiya
  class GrowiClipperTest < TestCase
    def disable?
      return true unless controller_class.growi?
      return true unless (account.growi rescue nil)
      return super
    end

    def test_create
      assert_kind_of(GrowiClipper, account.growi)
    end

    def test_clip
      r = account.growi.clip(body: "#{Time.now} #{__method__}")

      assert_kind_of(HTTParty::Response, r)
      assert_equal(201, r.code)
    end
  end
end
