module MulukhiyaTootProxy
  class DropboxClippingHandlerTest < Test::Unit::TestCase
    def setup
      config = Config.instance
      @handler = Handler.create('dropbox_clipping')
      @handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
    end

    def test_create
      assert(@handler.is_a?(DropboxClippingHandler))
    end

    def test_exec
      @handler.exec({'status' => Time.now.to_s})
      assert_equal(@handler.result, 'DropboxClippingHandler,0')
      sleep(1)

      @handler.exec({'status' => "#{Time.now} \#dropbox"})
      assert_equal(@handler.result, 'DropboxClippingHandler,1')
      sleep(1)
    end
  end
end
