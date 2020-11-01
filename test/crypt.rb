module Mulukhiya
  class CryptTest < TestCase
    def setup
      @crypt = Crypt.new
      @config = Config.instance
    end

    def test_encrypt
      @config['/crypt/encoder'] = 'base64'
      encrypted = @crypt.encrypt('hogehoge')
      decrypted = @crypt.decrypt(encrypted)
      assert_equal(decrypted, 'hogehoge')

      @config['/crypt/encoder'] = 'hex'
      encrypted = @crypt.encrypt('fugafuga')
      decrypted = @crypt.decrypt(encrypted)
      assert_equal(decrypted, 'fugafuga')

      @config['/crypt/encoder'] = 'huga'
      assert_raise RuntimeError do
        encrypted = @crypt.encrypt('fugafuga')
      end
      assert_raise RuntimeError do
        decrypted = @crypt.decrypt(encrypted)
      end
    end
  end
end
