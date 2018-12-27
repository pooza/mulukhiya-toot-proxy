module MulukhiyaTootProxy
  class GrowiClipperTest < Test::Unit::TestCase
    def setup
      config = Config.instance
      mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
      @clipper = GrowiClipper.create({account_id: mastodon.account_id})
    end

    def test_create
      assert_true(@clipper.is_a?(GrowiClipper))
    end

    def test_clip
      assert_true(@clipper.clip("#{Time.now} #{__method__}").is_a?(CPApiReturn))
    end
  end
end
