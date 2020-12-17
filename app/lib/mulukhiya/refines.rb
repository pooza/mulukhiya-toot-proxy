module Mulukhiya
  module Refines
    class ::String
      def encrypt
        return Crypt.new.encrypt(self)
      rescue Ginseng::AuthError
        return nil
      end

      def decrypt
        return Crypt.new.decrypt(self)
      rescue Ginseng::AuthError
        return nil
      end
    end

    class ::Time
      def xmlschema(fraction_digits = 0)
        fraction_digits = fraction_digits.to_i
        s = strftime('%FT%T')
        s << strftime(".%#{fraction_digits}N") if fraction_digits.positive?
        s << (utc? ? 'Z' : strftime('%:z'))
      end
    end
  end
end
