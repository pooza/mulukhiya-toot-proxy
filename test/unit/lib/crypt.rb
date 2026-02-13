module Mulukhiya
  class CryptTest < TestCase
    def setup
      @crypt = Crypt.new
    end

    def test_encrypt
      config['/crypt/encoder'] = 'base64'
      encrypted = @crypt.encrypt('hogehoge')
      decrypted = @crypt.decrypt(encrypted)

      assert_equal('hogehoge', decrypted)

      config['/crypt/encoder'] = 'hex'
      encrypted = @crypt.encrypt('fugafuga')
      decrypted = @crypt.decrypt(encrypted)

      assert_equal('fugafuga', decrypted)

      config['/crypt/encoder'] = 'huga'
      assert_raise Ginseng::CryptError do
        @crypt.encrypt('fugafuga')
      end

      assert_equal('fugafuga', decrypted)
      assert_raise Ginseng::CryptError do
        @crypt.decrypt('fugafuga')
      end
    end
  end
end
