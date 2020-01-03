module MulukhiyaTootProxy
  class GrowiClipperTest < TestCase
    def setup
      @clipper = Environment.test_account.growi
    end

    def test_create
      assert(@clipper.is_a?(GrowiClipper))
    end

    def test_clip
      assert(@clipper.clip("#{Time.now} #{__method__}").is_a?(CPApiReturn))
    end
  end
end
