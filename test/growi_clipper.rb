module MulukhiyaTootProxy
  class GrowiClipperTest < Test::Unit::TestCase
    def setup
      @clipper = GrowiClipper.create(account_id: Environment.sns_class.new.account.id)
    end

    def test_create
      assert(@clipper.is_a?(GrowiClipper))
    end

    def test_clip
      assert(@clipper.clip("#{Time.now} #{__method__}").is_a?(CPApiReturn))
    end
  end
end
