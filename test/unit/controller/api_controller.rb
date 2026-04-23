module Mulukhiya
  class APIControllerTest < TestCase
    def setup
      config['/crypt/password'] = SecureRandom.hex(32)
      config['/crypt/encoder'] = 'base64'
      @plain = SecureRandom.hex(32)
      @controller = APIController.new!
    end

    def test_token_bearer_decrypts_encrypted
      encrypted = @plain.encrypt
      set_request(headers: {'Authorization' => "Bearer #{encrypted}"})

      assert_equal(@plain, @controller.token)
    end

    def test_token_bearer_passes_plain_through
      set_request(headers: {'Authorization' => "Bearer #{@plain}"})

      assert_equal(@plain, @controller.token)
    end

    def test_token_body_decrypts_encrypted
      encrypted = @plain.encrypt
      set_request(body: {token: encrypted})

      assert_equal(@plain, @controller.token)
    end

    def test_token_body_passes_plain_through
      set_request(body: {token: @plain})

      assert_equal(@plain, @controller.token)
    end

    def test_token_returns_nil_when_absent
      set_request

      assert_nil(@controller.token)
    end

    private

    def set_request(headers: {}, body: {})
      @controller.instance_variable_set(:@headers, headers)
      @controller.instance_variable_set(:@params, Sinatra::IndifferentHash.new.merge(body))
      @controller.define_singleton_method(:params) do
        @params
      end
    end
  end
end
