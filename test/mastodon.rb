module MulukhiyaTootProxy
  class MastodonTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @mastodon = Mastodon.new(@config['/instance_url'], @config['/test/token'])
    end

    def test_new
      assert_true(@mastodon.is_a?(Mastodon))
    end

    def test_account_id
      assert_true(@mastodon.account_id.is_a?(Integer))
    end

    def test_account
      assert_true(@mastodon.account.is_a?(Hash))
    end

    def test_growi
      assert_true(@mastodon.growi.is_a?(Growi))
    end

    def test_create_tag
      assert_equal(Mastodon.create_tag('宮本佳那子'), '#宮本佳那子')
      assert_equal(Mastodon.create_tag('宮本 佳那子'), '#宮本_佳那子')
      assert_equal(Mastodon.create_tag('宮本 佳那子 '), '#宮本_佳那子')
    end
  end
end
