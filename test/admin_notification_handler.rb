module MulukhiyaTootProxy
  class AdminNotificationHandlerTest < TestCase
    def setup
      @handler = Handler.create('admin_notification')
      return if invalid_handler?
      @account = Environment.account_class.get(token: Config.instance['/test/token'])
      @params = {results: ResultContainer.new}
      @params[:results].response = {'id' => @account.id}
    end

    def test_handle_post_toot
      return if invalid_handler?

      @handler.clear
      @handler.handle_post_toot({message_field => 'ふつうのトゥート。'}, @params)
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_toot({message_field => "周知を含むトゥートのテスト\n#notify"}, @params)
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
