module MulukhiyaTootProxy
  class GrowiClipperTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @clipper = GrowiClipper.create(account_id: Environment.sns_class.new.account.id)
    end

    def test_create
      return if Environment.ci?
      assert(@clipper.is_a?(GrowiClipper))
    end

    def test_clip
      return if Environment.ci?
      assert(@clipper.clip("#{Time.now} #{__method__}").is_a?(CPApiReturn))
    end
  end
end
