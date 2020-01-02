module MulukhiyaTootProxy
  class DropboxClipperTest < TestCase
    def setup
      @clipper = Environment.sns_class.new.account.dropbox
    end

    def test_create
      assert(@clipper.is_a?(DropboxClipper))
    end

    def test_clip
      assert(@clipper.clip("#{Time.now} #{__method__}").is_a?(DropboxApi::Metadata::File))
    end
  end
end
