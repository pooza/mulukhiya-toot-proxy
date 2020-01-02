module MulukhiyaTootProxy
  class DropboxClipperTest < TestCase
    def setup
      @clipper = DropboxClipper.create(account_id: Environment.sns_class.new.account.id)
    end

    def test_create
      assert(@clipper.is_a?(DropboxClipper))
    end

    def test_clip
      @dropbox.clip("#{Time.now} #{__method__}")
    end
  end
end
