module MulukhiyaTootProxy
  class GrowiClipperTest < Test::Unit::TestCase
    def setup
      return if ENV['CI'].present?
      @clipper = GrowiClipper.create({account_id: Mastodon.new.account_id})
    end

    def test_create
      return if ENV['CI'].present?
      assert(@clipper.is_a?(GrowiClipper))
    end

    def test_clip
      return if ENV['CI'].present?
      assert(@clipper.clip("#{Time.now} #{__method__}").is_a?(CPApiReturn))
    end
  end
end
