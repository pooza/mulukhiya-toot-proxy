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
  end
end
