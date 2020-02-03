require 'openssl'
require 'base64'

module Mulukhiya
  class Crypt
    GLUE = '::::'.freeze

    def initialize
      @config = Config.instance
      @logger = Logger.new
    end

    def encrypt(plaintext, bit = 256)
      salt = create_salt
      enc = create_aes(bit)
      enc.encrypt
      keyiv = create_key_iv(password, salt, enc)
      enc.key = keyiv[:key]
      enc.iv = keyiv[:iv]
      encrypted = enc.update(plaintext) + enc.final
      return [encode_base64(encrypted), encode_base64(salt)].join(GLUE)
    rescue => e
      @logger.error(e)
    end

    def decrypt(encrypted, bit = 256)
      encrypted, salt = encrypted.split(GLUE).map {|v| decode_base64(v)}
      dec = create_aes(bit)
      dec.decrypt
      keyiv = create_key_iv(password, salt, dec)
      dec.key = keyiv[:key]
      dec.iv = keyiv[:iv]
      return dec.update(encrypted) + dec.final
    rescue => e
      @logger.error(e)
    end

    private

    def create_salt
      return OpenSSL::Random.random_bytes(8)
    end

    def create_aes(bit)
      return OpenSSL::Cipher::AES.new(bit, :CBC)
    end

    def create_key_iv(password, salt, aes)
      keyiv = OpenSSL::PKCS5.pbkdf2_hmac(
        password,
        salt,
        2000,
        aes.key_len + aes.iv_len,
        'sha256',
      )
      return {
        key: keyiv[0, aes.key_len],
        iv: keyiv[aes.key_len, aes.iv_len],
      }
    end

    def encode_base64(string)
      return Base64.strict_encode64(string).chomp
    end

    def decode_base64(string)
      return Base64.strict_decode64(string)
    end

    def password
      return @config['/crypt/password']
    end
  end
end
