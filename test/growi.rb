module MulukhiyaTootProxy
  class GrowiTest < Test::Unit::TestCase
    def test_create
      config = Config.instance
      mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
      assert_true(Growi.create({account_id: mastodon.account_id}).is_a?(Growi))
    end
  end
end
