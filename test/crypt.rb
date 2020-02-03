module Mulukhiya
  class CryptTest < TestCase
    def setup
      @crypt = Crypt.new
    end

    def test_encrypt
      encrypted = @crypt.encrypt('hogehoge')
      decrypted = @crypt.decrypt(encrypted)
      assert_equal(decrypted, 'hogehoge')
    end
  end
end
