module Mulukhiya
  class DropboxClipperTest < TestCase
    def test_create
      assert_kind_of(DropboxClipper, account.dropbox)
    end

    def test_clip
      assert_kind_of(DropboxApi::Metadata::File, account.dropbox.clip("#{Time.now} #{__method__}"))
    end
  end
end
