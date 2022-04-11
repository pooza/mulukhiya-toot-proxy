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
      def log(values = {})
        Logger.new.error({error: self}.merge(values))
        warn(to_h.deep_stringify_keys.to_yaml) if Environment.test? && Environment.development?
      end

      def alert(values = {})
        log(values)
        Event.new(:alert).dispatch(self)
      end

      def source_class
        return self.class
      end
    end
  end
end
