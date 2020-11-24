module Mulukhiya
  module Refines
    class ::String
      def escape_toot
        return sub(/[@#]/, '\\0 ')
      end

      alias escape_note escape_toot

      def encrypt
        return Crypt.new.encrypt(self)
      end

      def decrypt
        return Crypt.new.decrypt(self)
      end
    end
  end
end
