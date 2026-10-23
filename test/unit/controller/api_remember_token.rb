module Mulukhiya
  # `GET /mulukhiya/api/config` の保存トークン（5.43.0 のリリース前レビュー）。
  #
  # ⚠ 読み取り専用のトークンで /config を読むと、保存トークンが置き換わり、Webhook と
  # デコレーションの worker が以後 403 で落ちていた。GET は #4845 の判定の外。
  class APIRememberTokenTest < TestCase
    UserConfigDouble = Struct.new(:token)

    def setup
      @controller = APIController.new!
      @controller.define_singleton_method(:token) {'request_token'}
    end

    def test_remembers_writable_token
      config = stub_sns(writable: true)
      @controller.send(:remember_token)

      assert_equal('request_token', config.token)
    end

    def test_keeps_stored_token_for_read_only_token
      config = stub_sns(writable: false)
      @controller.send(:remember_token)

      assert_equal('stored_token', config.token)
    end

    private

    def stub_sns(writable:)
      config = UserConfigDouble.new('stored_token')
      account = Struct.new(:user_config).new(config)
      sns = Struct.new(:account, :writable) do
        def writable_token?
          return writable
        end
      end.new(account, writable)
      @controller.define_singleton_method(:sns) {sns}
      return config
    end
  end
end
