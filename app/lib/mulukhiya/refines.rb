module Mulukhiya
  module Refines
    class ::String
      def escape_toot
        return sub(/[@#]/, '\\0 ')
      end

      alias escape_note escape_toot

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

    class ::Array
      def deep_compact
        return clone.deep_compact!
      end

      def deep_compact!
        each do |value|
          if ['Array', 'Hash'].freeze.member?(value.class.to_s)
            value.deep_compact!
            delete(value) if value.empty?
          elsif value.nil?
            delete(value)
          end
        end
        compact!
        return self
      end
    end

    class ::Hash
      def deep_compact
        return clone.deep_compact!
      end

      def deep_compact!
        each do |key, value|
          if ['Array', 'Hash'].freeze.member?(value.class.to_s)
            value.deep_compact!
            delete(key) if value.empty?
          elsif value.nil?
            delete(key)
          end
        end
        compact!
        return self
      end
    end
  end
end
