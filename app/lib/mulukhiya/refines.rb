module Mulukhiya
  module Refines
    class ::String
      def encrypt
        return Crypt.new.encrypt(self)
      end

      def decrypt
        return Crypt.new.decrypt(self)
      end
    end

    class ::StandardError
      def alert(values = {})
        log(values)
        Event.new(:alert).dispatch(self)
      end
    end
  end
end
