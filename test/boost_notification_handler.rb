module MulukhiyaTootProxy
  class BoostNotificationHandlerTest < Test::Unit::TestCase
    def setup
      return unless Postgres.config?
      @config = Config.instance
      @handler = Handler.create('boost_notification')
      @account = Environment.account_class.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_handle_post_boost
      return unless Postgres.config?
      return if @handler.disable?

      @handler.clear
      @handler.handle_post_boost('id' => 0)
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_boost('id' => @toot.id)
      assert(@handler.result[:entries].first[:status_id].positive?)
      assert_equal(@handler.result[:entries].first[:status_id], @toot.id)
    end
  end
end
