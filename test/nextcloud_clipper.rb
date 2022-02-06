module Mulukhiya
  class NextcloudClipperTest < TestCase
    def test_create
      assert_kind_of(NextcloudClipper, account.nextcloud)
    end

    def test_clip
      assert_kind_of(HTTParty::Response, account.nextcloud.clip("#{Time.now} #{__method__}"))
    end
  end
end
