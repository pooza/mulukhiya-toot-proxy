module Mulukhiya
  class Crypt < Ginseng::Crypt
    include Package

    def encrypt(plaintext, bit = 256)
      case encoder
      when 'base64'
        return super
      when 'hex'
        salt = create_salt
        enc = OpenSSL::Cipher.new("AES-#{bit}-CBC")
        enc.encrypt
        keyiv = create_key_iv(password, salt, enc)
        enc.key = keyiv[:key]
        enc.iv = keyiv[:iv]
        encrypted = enc.update(plaintext) + enc.final
        return [encrypted.bin2hex, salt.bin2hex].join(GLUE)
      else
        raise "Invalid encoder 'base64'"
      end
    end

    def decrypt(joined, bit = 256)
      case encoder
      when 'base64'
        return super
      when 'hex'
        encrypted, salt = joined.split(GLUE).map(&:hex2bin)
        dec = OpenSSL::Cipher.new("AES-#{bit}-CBC")
        dec.decrypt
        keyiv = create_key_iv(password, salt, dec)
        dec.key = keyiv[:key]
        dec.iv = keyiv[:iv]
        return dec.update(encrypted) + dec.final
      else
        raise "Invalid encoder 'base64'"
      end
    end

    def encoder
      return @config['/crypt/encoder']
    end
  end
end
